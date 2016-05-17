defmodule Main do
  use Application

  def start(_type, _args) do

    import Supervisor.Spec, warn: false
    IO.inspect self

    children = [
      worker(MessageBus, []),
      worker(Cqrex.Repo, []),
      worker(User.CommandHandler, []),
      worker(User.WriteRepository, []),
      worker(User.ReadRepository, [])
    ]

    opts = [strategy: :one_for_one, name: Main.Supervisor]
    res = Supervisor.start_link(children, opts)

    MessageBus.subscribe(User.WriteRepository, [ :events, :changes ])
    MessageBus.subscribe(User.ReadRepository,  :events)
    MessageBus.subscribe(User.CommandHandler,  :commands)

    user = User.WriteRepository.new_model
    |> User.CommandHandler.create("Hola x")
    |> User.CommandHandler.change_name("Hola 5")

    :timer.sleep(900)
    user
    |> User.CommandHandler.change_name("Hola 6")
    |> User.WriteRepository.save
    :timer.sleep(1000)

    # :timer.sleep(50)
    # # time = Ecto.DateTime.utc(:usec)
    #
    # user
    # |> UserCommandHandler.change_name("Hola 6")
    # |> UserCommandHandler.change_name("Hola 8")
    #
    # :timer.sleep(500)
    # IO.inspect UserWriteRepository.all
    # UserWriteRepository.save_all
    # :timer.sleep(50)
    # IO.puts UserWriteRepository.find(user.uuid).name
    # UserCommandHandler.change_name(user, "Hola 9")
    # :timer.sleep(50)
    # UserWriteRepository.save user
    # IO.puts "HOLA"
    # :timer.sleep(50)
    # # IO.inspect UserQueryHandler.find user.uuid
    # :timer.sleep(600)
    # # IO.puts UserReadRepository.find_at(user.uuid, time).name
    # :timer.sleep(500)

    IO.inspect User.CommandHandler.get_commands

    res

  end

end

defmodule User.WriteRepository do
  use Cqrex.Repository, model: User
end

defmodule User.ReadRepository do
  use Cqrex.Repository, model: User
end

defmodule User do

  use Cqrex.AggregateRoot

  schema "users" do
    field :name, :string
  end

  event :created do
    %User{ self | name: e["name"] }
  end

  event :name_changed do
    %User{ self | name: e["new_name"] }
  end

end

defmodule User.CommandHandler do

  @repo User.WriteRepository
  use Cqrex.CommandHandler

  # Commands

  command create(name: name) do
    publish self, :created, %{
      "name" => name
    }
  end

  command change_name(new_name: name) do
    publish self, :name_changed, %{
      "new_name" => name
    }
  end

end

defmodule User.QueryHandler do

  @repo User.ReadRepository
  use Cqrex.QueryHandler

  # Queries

  query find(uuid) do
    @repo.find uuid
  end

  query all() do
    @repo.all
  end

end
