defmodule Main do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    children = [
      worker(MessageBus, []),
      worker(Cqrs.Repo, []),
      worker(UserCommandHandler, []),
      worker(UserRepository, [])
    ]
    opts = [strategy: :one_for_one, name: Main.Supervisor]
    res = Supervisor.start_link(children, opts)
    MessageBus.subscribe(UserRepository, :events)
    MessageBus.subscribe(UserCommandHandler, :commands)
    GenServer.cast(UserCommandHandler, { :create, %{ name: "hola" } })
    :timer.sleep(500)
    UserRepository.save_all
    :timer.sleep(500)
    res
  end

end

defmodule User do

  use Cqrs.AggregateRoot

  defstruct uuid: nil, name: nil

  event :created, do: %User{ self | name: e.name }
  event :name_changed, do: %User{ self | name: e.new_name}

  def new, do: %User{}

  def create(user, name), do:
    source(user, { :created, %{ name: name } })

  def change_name(user, new_name), do:
    source(user, { :name_changed, %{ new_name: new_name } })

end

defmodule UserRepository do
  use Cqrs.Repository, model: User
end

defmodule UserCommandHandler do

  use Cqrs.CommandHandler
  require User

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
    User.create(self, e.name)

  command :change_name, do:
    User.change_name(self, e.new_name)

end
