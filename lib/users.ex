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

    uuid = Cqrs.make_uuid
    UserCommandHandler.create uuid, "Hola x"
    UserCommandHandler.change_name uuid, "Hola 2"

    # [ name: name ]

    :timer.sleep(500)
    IO.puts UserRepository.find(uuid).name
    UserRepository.save_all
    :timer.sleep(500)
    res
  end

end

defmodule User do

  use Cqrs.AggregateRoot

  schema "users" do
    field :name, :string
  end

  event :created, do: %User{ self | name: e.name }
  event :name_changed, do: %User{ self | name: e.new_name}

end

defmodule UserRepository do
  use Cqrs.Repository, model: User
end

defmodule UserCommandHandler do

  @repo UserRepository
  use Cqrs.CommandHandler
  require User

  ## Commands

  command :create, [ name: name ] do
    publish self, :created, %{name: name}
  end

  command :change_name, [ new_name: name ] do
    publish self, :name_changed, %{new_name: name}
  end

end
