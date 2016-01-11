defmodule CqrsTest do
  use ExUnit.Case
  doctest User

  test "commands" do
    assert (UserRepository.all |> Enum.count) == 0
    GenServer.cast(UserCommandHandler, {
      :create, %{ name: "John" }
    })
    assert (UserRepository.all |> Enum.count) == 1
    user = UserRepository.all |> List.first
    assert user.name == "John"
    GenServer.cast(UserCommandHandler, {
      :change_name, %{
         uuid: user.uuid,
         new_name: "Jack"
      }
    })
    assert UserRepository.find(user.uuid).name == "Jack"
    { :ok, GenServer.whereis(Main.Supervisor) }
  end

end
