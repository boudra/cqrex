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

defmodule Cqrs.MessageHandler do


end

defmodule Cqrs.QueryHandler do
  import Cqrs.MessageHandler
  defmacro query({name, _, args}, expr) do
    quote do
      def handle({unquote(name), unquote_splicing(args) }), unquote(expr)
      def unquote(name)(unquote_splicing(args)), unquote(expr)
    end
  end
  defmacro __using__(_opts) do
    quote do
      import Cqrs
      import Cqrs.QueryHandler
    end
  end
end

defmodule Cqrs.CommandHandler do

  import Cqrs.MessageHandler
  defmacro command({type, _, named_args},  expr) when is_atom(type) and is_list(named_args) do

    real_args = [ :self | named_args |> Enum.map(fn(arg) ->
      {_, {x,_,_} } = (arg |> List.first)
      x
    end)] |> Enum.map(&({ &1, [], nil }))
    command_map = {:%{}, [], named_args |> Enum.map(&List.first/1)}

    Module.put_attribute(__CALLER__.module, :commands, [
      type | Module.get_attribute(__CALLER__.module, :commands)
    ])

    quote do

      def handle(var!(self), unquote(type), unquote(command_map)), unquote(expr)

      def unquote(type)(unquote_splicing(real_args)) do
        unquote(__CALLER__.module).send(
          unquote(:"#{type}"),
          unquote({:self, [], nil}),
          unquote(command_map)
        )
        unquote({:self, [], nil})
      end

    end
  end

  defmacro __using__(_opts) do
    Module.put_attribute(__CALLER__.module, :commands, [])
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

      def send(type, aggregate, payload) when(is_map(aggregate)) do
        GenServer.cast(__MODULE__, { type, aggregate.uuid, payload })
      end

      def send(type, aggregate, payload) do
        GenServer.cast(__MODULE__, { type, aggregate, payload })
      end

      def publish(model, event_type, payload) do
        "Elixir." <> name = "#{model.__struct__}"
        MessageBus.publish(:changes, Cqrs.make_event(
          event_type,
          Macro.underscore(name),
          model.uuid,
          payload
        ))
        model.__struct__.handle(model, {event_type, payload})
      end

      def get_commands() do
        @commands
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
      import Ecto.Query, only: [from: 2]
      require Ecto.Changeset

      def handle_call({ :get_all }, _from, state), do:
        {:reply, state.items, state}

      def handle_call({ :find_by_id, uuid }, _from, state) do
        {:reply, Cqrs.Repo.get(unquote(model_name), uuid), state}
      end

      def handle_call({ :exists, uuid }, _from, state) do
        {:reply, !!Cqrs.Repo.get(unquote(model_name), uuid), state}
      end

      def handle_call({:find_at, uuid, time}, _from ,state) do

        "Elixir." <> name = "#{unquote(model_name)}"
        name = Macro.underscore(name)

        query = from e in Cqrs.Event,
          where: e.aggregate_type == ^name,
          where: e.aggregate_uuid == ^uuid,
          where: e.timestamp < ^time,
          order_by: e.timestamp,
          select: e

        events = Cqrs.Repo.all(query)

        model = Enum.reduce(events, new_model(uuid),
          &(unquote(model_name).handle(&2,{&1.type, &1.payload})))

        {:reply, model, state}
      end

      defp change(changes, uuid, new_changes) do
        changeset = Enum.find(
          changes,
          Ecto.Changeset.change(struct(unquote(model_name))),
          &(&1.model.uuid == uuid)
        )
        changeset = Ecto.Changeset.change(changeset, Map.from_struct(new_changes))
        %Ecto.Changeset{ changeset | model: new_changes }
      end

      defp apply_event(items, event) do
        entity = case Cqrs.Repo.get(unquote(model_name), event.aggregate_uuid) do
          nil -> new_model(event.aggregate_uuid)
          model -> model
        end
        new_model = unquote(model_name).handle(entity, {event.type, event.payload})
        changeset = change(items, event.aggregate_uuid, new_model)
        [ changeset | items |> Enum.filter(&(&1.model.uuid != changeset.model.uuid)) ]
      end

      def handle_cast({ :events, event }, state) do
        {:noreply, %State{ state | items: apply_event(state.items, event) }}
      end

      def handle_cast({ :changes, event }, state) do
        {
          :noreply, %State{
            changes: [event | state.changes],
            items: apply_event(state.items, event)
          }
        }
      end

      def handle_cast({ :save_all }, state) do
        IO.puts "saving..."
        state = Enum.reduce(state.items, state, fn(item, state) ->
          { :noreply, state } = handle_cast({ :save, item.model }, state)
          state
        end)
        { :noreply, state }
      end

      def handle_cast({ :save, model }, state) do
        changes = state.changes |> Enum.filter(&(&1.aggregate_uuid == model.uuid))
        rest_changes = state.changes |> Enum.reject(&(&1.aggregate_uuid == model.uuid))
        Enum.each(changes, fn(change) ->
          MessageBus.publish :events, change
          Cqrs.Repo.insert(change)
        end)
        Cqrs.Repo.insert_or_update!(Enum.find(
          state.items,
          nil,
          &(&1.model.uuid == model.uuid)))
        items = state.items |> Enum.filter(&(&1.model.uuid != model.uuid))
        { :noreply, %State{ changes: rest_changes, items: items } }
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

      def save(model), do:
        GenServer.cast(__MODULE__, { :save, model })

      def find(uuid), do:
        GenServer.call(__MODULE__, { :find_by_id, uuid })

      def find_at(uuid, time), do:
        GenServer.call(__MODULE__, { :find_at, uuid, time })

      def exists?(uuid), do:
        GenServer.call(__MODULE__, { :exists, uuid })

      def apply_event(event), do:
        GenServer.cast(__MODULE__, { :events, event })

      def new_model(uuid \\ nil) do
        struct(unquote(model_name))
        |> Map.put(:uuid, (is_nil(uuid) && Cqrs.make_uuid || uuid))
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
