defmodule User do

  defstruct name: nil, uuid: nil, changes: []

  defmodule Events do
    defmodule Created do
      defstruct name: nil, uuid: nil
    end
  end

  defmodule Commands do
    defmodule Create do
      defstruct name: nil, uuid: nil
    end
  end

  def dispatch(user, message) do
    user = %{user | changes: [message|user.changes]}
    handle(user, message)
  end

  def handle(user, %Events.Created{name: name, uuid: uuid}) do
    %{user | name: name, uuid: uuid}
  end

  def new do
    %User{}
  end

end

defmodule UserRepository do

  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, :ok, [])
  end

  def init(:ok) do
    {:ok, %{}}
  end

  def handle_cast({:command, message}, state) do
    IO.inspect "Got #{inspect message} in process #{inspect self()}"
    user = command(message)
    {:noreply, Map.put(state, user.uuid, user)}
  end

  def handle_call({:hola}, _wat, state) do
    {:reply, state, state}
  end

  def command(%User.Commands.Create{name: name, uuid: uuid}) do
    user = User.new
    user = User.dispatch(user, %User.Events.Created{name: name, uuid: uuid})
    user
  end

  def create(repository, name) do
    GenServer.cast(repository, {:command, %User.Commands.Create{name: name, uuid: Kernel.make_ref}})
  end

  def get_all(repository) do
    GenServer.call(repository, {:hola})
  end

end

defmodule Main do
  use Application

  def start(_type, _args) do
    # import Supervisor.Spec, warn: false
    # children = [
    #   worker(UserRepository, [])
    # ]
    # opts = [strategy: :one_for_one, name: Main.Supervisor]
    # Supervisor.start_link(children, opts)
    {:ok, pid} = UserRepository.start_link
    UserRepository.create(pid, "hola")
    all = UserRepository.get_all(pid)
    IO.inspect all
    {:ok, pid}
  end

end
