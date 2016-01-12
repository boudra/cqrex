defmodule CqrsTest do
  use ExUnit.Case
  doctest User

  test "repository exists call" do

    assert match?(
    {:reply, false, %Cqrs.Repository.State{changes: [], items: []}},
    UserRepository.handle_call({ :exists, "42" }, self,
      %Cqrs.Repository.State{
      items: [],
      changes: []
    }))

    assert match?(
    {:reply, true, %Cqrs.Repository.State{changes: [], items: [
          %User{ name: "hola", uuid: "42" }
    ]}},
    UserRepository.handle_call({ :exists, "42" }, self,
      %Cqrs.Repository.State{
      items: [
          %User{ name: "hola", uuid: "42" }
      ],
      changes: []
    }))

  end

  test "find by id" do

    assert match?(
    {
      :reply,
      %User{ name: "hola", uuid: "42" },
      %Cqrs.Repository.State{
        changes: [],
        items: [
          %User{ name: "hola", uuid: "42" }
        ]
      }
    },
    UserRepository.handle_call({
      :find_by_id, "42"
    }, self,
    %Cqrs.Repository.State{
    items: [
        %User{ name: "hola", uuid: "42" }
    ],
    changes: []
    }))

  end

  test "event sourcing" do

    assert match?(
    {
      :reply,
      %User{ name: "hola", uuid: _ },
      %Cqrs.Repository.State{
        changes: [],
        items: [
          %User{ name: "hola", uuid: "42" }
        ]
      }
    },
    UserRepository.handle_call({
      :find_by_id, "42"
    }, self,
    %Cqrs.Repository.State{
    items: [
        %User{ name: "hola", uuid: "42" }
    ],
    changes: []
    }))

  end

end
