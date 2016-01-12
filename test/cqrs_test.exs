defmodule CqrsTest do
  use ExUnit.Case
  doctest User

  test "" do
    GenServer.cast(UserCommandHandler, { :create, %{ name: "hola" } })
    :timer.sleep(1000)
  end

end
