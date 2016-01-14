defmodule Cqrs do

  defmodule Repo do
    use Ecto.Repo, otp_app: :cqrs
  end

  defmodule AtomType do
    @behaviour Ecto.Type
    def type, do: :string

    def cast(atom) when is_atom(atom), do:
      {:ok, Atom.to_string(atom) }

    def cast(string) when is_binary(string), do: {:ok, string}
    def cast(_), do: :error

    def load(string) when is_binary(string), do:
      {:ok, String.to_existing_atom(string) }

    def load(_), do: :error

    def dump(value), do: cast(value)

  end

  defmodule Event do
    use Ecto.Schema

    @primary_key {:uuid, Ecto.UUID, [read_after_writes: true]}
    schema "events" do
      field :timestamp, Ecto.DateTime
      field :aggregate_uuid, Ecto.UUID
      field :aggregate_type, :string
      field :type, Cqrs.AtomType
      field :payload, :map
    end

  end

  def make_uuid, do:
    Ecto.UUID.generate

  def make_event(type, aggregate_type, aggregate, payload) do
    %Event{
      uuid: Cqrs.make_uuid,
      aggregate_type: aggregate_type,
      aggregate_uuid: aggregate,
      timestamp: Ecto.DateTime.utc(:usec),
      type: type,
      payload: payload
    }
  end

end

defmodule Cqrs.CommandHandler do
  defmacro command(type, args \\ nil, expr) do
    real_args = [ :uuid | args |> Enum.map(fn(arg) ->
      {_,{x,_,_}} = arg
      x
    end)] |> Enum.map(&({ &1, [], nil }))

    quote do

      def handle(var!(self), unquote(:"#{type}"), %{ unquote_splicing(args) }) do
        unquote(expr)[:do]
      end

      def unquote(type)(unquote_splicing(real_args)) do
        unquote(__CALLER__.module).send(unquote(:"#{type}"), unquote({:uuid, [], nil}), %{ unquote_splicing(args) })
      end

    end
  end
  defmacro __using__(_opts) do
    quote do
      import Cqrs
      import Cqrs.CommandHandler
      use GenServer

      def handle_cast({ type, aggregate, message }, state) do
        aggregate
        |> state.__repository__.find_or_new
        |> handle(type, message)
        {:noreply, state }
      end

      def start_link, do:
        GenServer.start_link(__MODULE__,
          %{ __repository__: @repo },
          name: __MODULE__
        )

      def init(initial_state), do:
        {:ok, initial_state}

      def send(type, aggregate, payload) do
        GenServer.cast(__MODULE__, { type, aggregate, payload })
      end

      def publish(model, event_type, payload) do
        "Elixir." <> name = "#{model.__struct__}"
        MessageBus.publish(:events, Cqrs.make_event(
          event_type,
          Macro.underscore(name),
          model.uuid,
          payload
        ))
      end
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

      def handle_call({ :find_by_id, uuid }, _from, state) do
        {:reply, Enum.find(state.items, &(&1.uuid == uuid)), state}
      end

      def handle_call({ :exists, uuid }, _from, state) do
        {:reply, Enum.any?(state.items, &(&1.uuid == uuid)), state}
      end

      def handle_cast({ :events, event }, state) do
        entity = Enum.find(state.items, new_model(event.aggregate_uuid), &(&1.uuid == event.aggregate_uuid)) |> unquote(model_name).handle({event.type, event.payload})
        items = [ entity | state.items |> Enum.filter(&(&1.uuid != entity.uuid)) ]
        {:noreply, %State{ changes: [event | state.changes], items: items }}
      end

      def handle_cast({ :save_all }, state) do
        IO.puts "saving..."
        IO.inspect state.items
        Enum.each(state.changes, fn(item) ->
          Cqrs.Repo.insert(item)
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

      defp new_model(uuid) when is_nil(uuid), do: new_model(Cqrs.make_uuid)

      defp new_model(uuid) do
        struct(unquote(model_name)) |> Map.put(:uuid, uuid)
      end

      def find_or_new(uuid) do
        exists?(uuid) && find(uuid) || new_model(uuid)
      end

    end
  end
end

defmodule Cqrs.AggregateRoot do

  defmacro __using__(_opts) do
    quote do
      import Cqrs
      import Cqrs.AggregateRoot
      use Ecto.Schema
      @primary_key {:uuid, Ecto.UUID, [read_after_writes: true]}
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
