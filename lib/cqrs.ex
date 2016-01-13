defmodule Cqrs do

  defmodule Repo do
    use Ecto.Repo, otp_app: :cqrs
  end

  defmodule AtomType do
    @behaviour Ecto.Type
    def type, do: :string

    # Provide our own casting rules.
    def cast(atom) when is_atom(atom) do
      {:ok, Atom.to_string(atom) }
    end

    # We should still accept integers
    def cast(string) when is_binary(string), do: {:ok, string}

    # Everything else is a failure though
    def cast(_), do: :error

    # When loading data from the database, we are guaranteed to
    # receive an integer (as databases are strict) and we will
    # just return it to be stored in the model struct.
    def load(string) when is_binary(string), do: {:ok, string}

    # When dumping data to the database, we *expect* an integer
    # but any value could be inserted into the struct, so we need
    # guard against them.
    def dump(string) when is_binary(string), do: {:ok, string}
    def dump(_), do: :error
  end

  defmodule Event do
    use Ecto.Schema

    @primary_key {:uuid, Ecto.UUID, [read_after_writes: true]}
    schema "events" do
      field :timestamp, :integer
      field :type, AtomType
      field :payload, :map
    end

    def changeset(model, _ \\ nil) do
      %{ model | type: Atom.to_string(model.type) }
    end

  end

  def uuid, do:
    Ecto.UUID.generate

  def make_event({ type, payload}), do:
    %Event{
      uuid: uuid,
      timestamp: :os.system_time(:seconds),
      type: type,
      payload: payload
    }

end

defmodule Cqrs.CommandHandler do
  defmacro command(type, expr) do
    quote do
      def handle(var!(self), { unquote(:"#{type}"), var!(e) }) do
        unquote(expr)[:do]
      end
    end
  end
  defmacro __using__(_opts) do
    quote do
      import Cqrs
      import Cqrs.CommandHandler
      use GenServer
    end
  end
end

defmodule Cqrs.Repository do
  defmodule State, do: defstruct items: [], changes: []
  defmacro __using__(options) do

    model_name = Keyword.get(options, :model)

    quote do
      import Cqrs.Repository

      def handle_call({ :get_all }, _from, state), do:
        {:reply, state.items, state}

      def handle_call({ :find_by_id, uuid }, _from, state), do:
        {:reply, Enum.find(state.items, &(&1.uuid == uuid)), state}

      def handle_call({ :exists, uuid }, _from, state), do:
        {:reply, Enum.any?(state.items, &(&1.uuid == uuid)), state}

      def handle_cast({ :events, event }, state) do
        entity = Enum.find(state.items, struct(unquote(model_name)), &(&1.uuid == event.payload.uuid)) |> unquote(model_name).handle({event.type, event.payload})
        items = [ entity | state.items |> Enum.filter(&(&1.uuid != entity.uuid)) ]
        {:noreply, %State{ changes: [event | state.changes], items: items }}
      end

      def handle_cast({ :save_all }, state) do
        IO.inspect state
        IO.puts "saving.."
        Enum.each(state.changes, fn(item) ->
          Cqrs.Repo.insert(Cqrs.Event.changeset(item))
        end)
        {:noreply, %State{ changes: [], items: state.items }}
      end

      def start_link, do:
        GenServer.start_link(__MODULE__, %State{}, name: __MODULE__)

      def init(initial_state) do
        {:ok, initial_state}
      end

      def terminate(_, _) do
      end

      def all(), do:
        GenServer.call(__MODULE__, { :get_all })

      def save_all(), do:
        GenServer.cast(__MODULE__, { :save_all })

      def find(uuid), do:
        GenServer.call(__MODULE__, { :find_by_id, uuid })

      def exists?(uuid), do:
        GenServer.call(__MODULE__, { :exists, uuid })

      def apply_event(event), do:
        GenServer.cast(__MODULE__, { :events, event })

      def find_or_new(uuid) do
        exists?(uuid) && find(uuid) || struct(unquote(model_name))
      end

    end
  end
end

defmodule Cqrs.AggregateRoot do

  defmacro __using__(_opts) do
    quote do
      import Cqrs
      import Cqrs.AggregateRoot
      def source(model, message) do
        if MessageBus |> Process.whereis !== nil, do:
          MessageBus.publish(:events, make_event(message))
        handle(model, message)
      end
    end
  end

  defmacro event(type, expr) do
    quote do
      def handle(var!(self), { unquote(:"#{type}"), var!(e) }) do
        unquote(expr)[:do]
      end
    end
  end

end
