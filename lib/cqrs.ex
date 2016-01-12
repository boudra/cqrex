defmodule Cqrs do

  defmodule Event, do:
    defstruct uuid: nil,
              timestamp: nil,
              type: nil,
              payload: nil

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

    model = Keyword.get(options, :model, %{})

    quote do

      import Cqrs.Repository

      def handle_call({ :get_all }, _from, state), do:
        {:reply, state.items, state}

      def handle_call({ :find_by_id, uuid }, _from, state), do:
        {:reply, Enum.find(state.items, fn(item) -> item.uuid == uuid end), state}

      def handle_call({ :exists, uuid }, _from, state), do:
        {:reply, Enum.any?(state.items, fn(item) -> item.uuid == uuid end), state}

      def handle_cast({ :events, event }, state) do
        entity = Enum.find(state.items, unquote(model),
                         fn(item) -> item.uuid == event.payload.uuid end)
                 |> User.handle({event.type, event.payload})
        items = [ entity | state.items
                |> Enum.filter(fn(item) -> item.uuid != entity.uuid end) ]
        {:noreply, %State{ changes: [event | state.changes], items: items }}
      end

      def start_link, do:
        GenServer.start_link(__MODULE__, %State{}, name: __MODULE__)

      def init(initial_state) do
        {:ok, initial_state}
      end

      def all(), do:
        GenServer.call(__MODULE__, { :get_all })

      def find(uuid), do:
        GenServer.call(__MODULE__, { :find_by_id, uuid })

      def exists?(uuid), do:
        GenServer.call(__MODULE__, { :exists, uuid })

      def apply_event(event), do:
        GenServer.cast(__MODULE__, { :events, event })

      def find_or_new(uuid) do
        exists?(uuid) && find(uuid) || unquote(model)
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

