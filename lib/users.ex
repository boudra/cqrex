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

    user = UserRepository.new_model
           |> UserCommandHandler.create("Hola x")
           |> UserCommandHandler.change_name("Hola 5")

    :timer.sleep(50)
    time = Ecto.DateTime.utc(:usec)

    user
    |> UserCommandHandler.change_name("Hola 6")
    |> UserCommandHandler.change_name("Hola 8")

    :timer.sleep(500)
    IO.inspect UserRepository.all
    UserRepository.save_all
    :timer.sleep(50)
    IO.puts UserRepository.find(user.uuid).name
    UserCommandHandler.change_name(user, "Hola 9")
    :timer.sleep(50)
    UserRepository.save user
    :timer.sleep(600)
    IO.puts UserRepository.find_at(user.uuid, time).name
    :timer.sleep(500)
    res

  end

end

defmodule User do

  use Cqrs.AggregateRoot

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

defmodule UserRepository do
  use Cqrs.Repository, model: User
end

defmodule UserCommandHandler do

  @repo UserRepository
  use Cqrs.CommandHandler

  # Commands

  command :create, [ name: name ] do
    publish self, :created, %{ "name" => name}
  end

  command :change_name, [ new_name: name ] do
    publish self, :name_changed, %{ "new_name" => name}
  end

end
