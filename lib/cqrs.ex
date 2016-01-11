defmodule Cqrs do

  defmodule Event, do: defstruct uuid: nil, timestamp: nil, payload: nil

  defmacro __using__(_) do
    quote do
      import Cqrs

      def apply(user, message) do
        %{handle(user, message) | changes: [ make_event(message) | user.changes]}
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

  defmacro command(type, expr) do
    quote do
      def handle(var!(user), { unquote(:"#{type}"), var!(e) }) do
        unquote(expr)[:do]
      end
    end
  end

  def uuid, do: Kernel.make_ref

  def make_event(payload) do
    %Event{
      uuid: uuid,
      timestamp: :os.system_time(:seconds),
      payload: payload
    }
  end

end

defmodule User do

  use Cqrs

  defstruct name: nil, uuid: nil, changes: []

  event :created, do: %{user | name: e.name, uuid: e.uuid}
  event :name_changed, do: %{user | name: e.new_name}

  def new, do: %User{}

  def create(user, name) do
    User.apply(user, { :created, %{name: name, uuid: Cqrs.uuid } })
  end

  def change_name(user, new_name) do
    User.apply(user, { :name_changed, %{new_name: new_name, uuid: user.uuid } })
  end

end

defmodule UserCommandHandler do

  use GenServer
  import Cqrs

  def handle_cast({ type, message }, state) do
    user = (Map.has_key?(message, :uuid)
           && Map.get(state, message[:uuid]) || User.new)
           |> UserCommandHandler.handle({ type, message })
    # IO.inspect user.name
    {:noreply, Map.put(state, user.uuid, user)}
  end

  def handle_call({ :get_state }, _from, state) do
    {:reply, state, state}
  end

  def handle_call({ :find_by_id, uuid }, _from, state) do
    {:reply, Map.get(state, uuid), state}
  end

  ## Client API

  def start_link, do: GenServer.start_link(__MODULE__, :ok, [])
  def init(:ok), do: {:ok, %{}}

  def all(repository), do:
    GenServer.call(repository, { :get_state }) |> Map.values

  def find(repository, uuid), do:
    GenServer.call(repository, { :find_by_id, uuid })

  ## Commands

  command :create do
    User.create(user, e.name)
  end

  command :change_name do
    User.change_name(user, e.new_name)
  end

end

defmodule Main do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    children = [
      worker(UserCommandHandler, [])
    ]
    opts = [strategy: :one_for_one, name: Main.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
