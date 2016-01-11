defmodule Cqrs do

  defmodule Event, do: defstruct uuid: nil, timestamp: nil, payload: nil

  def uuid, do: Kernel.make_ref

  def event(payload) do
    %Event{
      uuid: uuid,
      timestamp: :os.system_time(:seconds),
      payload: payload
    }
  end

end

defmodule User do

  defstruct name: nil, uuid: nil, changes: []

  def apply(user, message) do
    user = %{user | changes: [ Cqrs.event(message) | user.changes]}
    IO.inspect message
    handle(user, message)
  end

  def handle(user, {:created, e}) do
    %{user | name: e.name, uuid: e.uuid}
  end

  def handle(user, {:name_changed, e}) do
    %{user | name: e.new_name}
  end

  def new do
    %User{}
  end

  def create(user, name) do
    User.apply(user, { :created, %{name: name, uuid: Cqrs.uuid } })
  end

  def change_name(user, new_name) do
    User.apply(user, { :name_changed, %{new_name: new_name, uuid: user.uuid } })
  end

end

defmodule UserCommandHandler do

  use GenServer

  def handle_cast({ type, message }, state) do
    user = (Map.has_key?(message, :uuid)
           && Map.get(state, message[:uuid]) || User.new)
           |> UserCommandHandler.command({ type, message })
    IO.inspect user.name
    {:noreply, Map.put(state, user.uuid, user)}
  end

  def handle_call({ :get_state }, _from, state) do
    {:reply, state, state}
  end

  def handle_call({ :find_by_id, uuid }, _from, state) do
    {:reply, Map.get(state, uuid), state}
  end

  def command(user, { :create, %{ name: name } }) do
    User.create(user, name)
  end

  def command(user, { :change_name, c }) do
    User.change_name(user, c.new_name)
  end

  ## Client API

  def start_link do
    GenServer.start_link(__MODULE__, :ok, [])
  end

  def init(:ok) do
    {:ok, %{}}
  end

  def all(repository) do
    GenServer.call(repository, { :get_state }) |> Map.values
  end

  def find(repository, uuid) do
    GenServer.call(repository, { :find_by_id, uuid })
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
