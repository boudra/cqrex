defmodule Cqrs do

  defmodule Event, do:
    defstruct uuid: nil,
              timestamp: nil,
              type: nil,
              payload: nil

  defmodule AggregateRoot do
    defmacro __using__(_opts) do
      quote do
        import Cqrs.AggregateRoot
        def apply(user, message) do
          UserRepository.apply_event(make_event(message))
          handle(user, message)
        end
      end
    end
    defmacro event(type, expr) do
      quote do
        def handle(var!(user), { unquote(:"#{type}"), var!(e) }) do
          unquote(expr)[:do]
          end
        end
      end
    end

    defmacro command(type, expr) do
      quote do
        def handle(var!(user), { unquote(:"#{type}"), var!(e) }) do
          unquote(expr)[:do]
          end
        end
      end

      defmodule Repository do
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

            def handle_cast({ :apply_change, event }, state) do
              user = Enum.find(state.items, unquote(model),
                               fn(item) -> item.uuid == event.payload.uuid end)
                     |> User.handle({event.type, event.payload})
              items = [ user | state.items
                      |> Enum.filter(fn(item) -> item.uuid != user.uuid end) ]
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
            GenServer.cast(__MODULE__, { :apply_change, event })

            def find_or_new(uuid) do
              exists?(uuid) && find(uuid) || unquote(model)
            end

          end
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

    defmodule User do

      import Cqrs
      use Cqrs.AggregateRoot

      defstruct uuid: nil, name: nil

      event :created, do: %{user | name: e.name, uuid: e.uuid}
      event :name_changed, do: %{user | name: e.new_name}

      def new, do: %User{}

      def create(user, name), do:
      User.apply(user, { :created, %{name: name, uuid: uuid } })

      def change_name(user, new_name), do:
      User.apply(user, { :name_changed, %{new_name: new_name, uuid: user.uuid } })

    end

    defmodule UserRepository do
      use Cqrs.Repository, model: User.new
    end

    defmodule UserCommandHandler do

      use GenServer
      import Cqrs

      def handle_cast({ type, message }, state) do
        Map.get(message, :uuid, nil)
        |> UserRepository.find_or_new
        |> UserCommandHandler.handle({ type, message })
        {:noreply, state }
      end

      def start_link, do:
      GenServer.start_link(__MODULE__, %{ repository: UserRepository }, name: __MODULE__)

      def init(initial_state), do:
      {:ok, initial_state}

      ## Commands

      command :create, do:
      User.create(user, e.name)

      command :change_name, do:
      User.change_name(user, e.new_name)

    end

    defmodule Main do
      use Application

      def start(_type, _args) do
        import Supervisor.Spec, warn: false
        children = [
          worker(UserCommandHandler, []),
          worker(UserRepository, [])
        ]
        opts = [strategy: :one_for_one, name: Main.Supervisor]
        Supervisor.start_link(children, opts)
      end

    end
