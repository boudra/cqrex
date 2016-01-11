defmodule CqrsTest do
  use ExUnit.Case
  doctest User

  test "commands" do
    {:ok, pid} = UserCommandHandler.start_link
    GenServer.cast(pid, { :create, %{ name: "John" } })
    uuid = UserCommandHandler.all(pid) |> List.first |> Map.get(:uuid)
    GenServer.cast(pid, { :change_name, %{ uuid: uuid, new_name: "Jack" } })
    assert UserCommandHandler.find(pid, uuid).name == "Jack"
    {:ok, pid}
  end

end
