defmodule CqrexTest do
  use ExUnit.Case
  doctest User

  test "repository exists call" do

    assert match?(
    {:reply, false, %Cqrex.Repository.State{changes: [], items: []}},
    UserRepository.handle_call({ :exists, "42" }, self,
      %Cqrex.Repository.State{
      items: [],
      changes: []
    }))

    assert match?(
    {:reply, true, %Cqrex.Repository.State{changes: [], items: [
          %User{ name: "hola", uuid: "42" }
    ]}},
    UserRepository.handle_call({ :exists, "42" }, self,
      %Cqrex.Repository.State{
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
      %Cqrex.Repository.State{
        changes: [],
        items: [
          %User{ name: "hola", uuid: "42" }
        ]
      }
    },
    UserRepository.handle_call({
      :find_by_id, "42"
    }, self,
    %Cqrex.Repository.State{
    items: [
        %User{ name: "hola", uuid: "42" }
    ],
    changes: []
    }))

  end

  test "that it should source the events" do

    assert match?(
    {
      :reply,
      %User{ name: "hola", uuid: _ },
      %Cqrex.Repository.State{
        changes: [],
        items: [
          %User{ name: "hola", uuid: "42" }
        ]
      }
    },
    UserRepository.handle_call({
      :find_by_id, "42"
    }, self,
    %Cqrex.Repository.State{
    items: [
        %User{ name: "hola", uuid: "42" }
    ],
    changes: []
    }))

  end

end
