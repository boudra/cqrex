defmodule Cart do

  use Cqrex.AggregateRoot

  defstruct [ :id, :items ]

  # Events

  def created(cart, %{ id: id, items: items }) do
    %Cart{ cart | id: id, items: items }
  end

  def item_added(cart, item) do
    %Cart{ cart | items: [ item | cart.items ] }
  end

  # Commands

  def create!(cart, id) do
    dispatch cart, :created, %{ id: id, items: [] }
  end

  def add_item!(cart, item) do
    case Enum.find(cart.items, &(&1 == item)) do
      nil -> dispatch cart, :item_added, item
      _ -> raise "Item already added" # yes it's a very limited cart
    end
  end

end

defmodule CqrexTest do
  use ExUnit.Case
  alias Cqrex.{AggregateRoot, EventStore}

  test "events get queued for saving" do

    cart = Cart.new
    |> Cart.create!(Cqrex.make_uuid)
    |> Cart.add_item!("Bike")
    |> Cart.add_item!("Orange")

    assert cart.items == [ "Orange", "Bike" ]
    assert Enum.count(cart.__events__) == 3
    assert Enum.all?(EventStore.get_events, fn(event) ->
      event.aggregate_type == Cart &&
      event.aggregate_uuid == cart.id
    end)

  end

  test "save events in event store" do

    cart = Cart.new
    |> Cart.create!(Cqrex.make_uuid)
    |> AggregateRoot.save!

    :timer.sleep(100) # eventual consistency, TODO: better test

    assert Enum.count(EventStore.get_events) == 1
    assert Enum.count(cart.__events__) == 0

  end

end
