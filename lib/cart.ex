defmodule Main do
  use Application

  def start(_type, _args) do

    import Supervisor.Spec, warn: false

    children = [
      worker(Cqrex.MessageBus, []),
      worker(Cqrex.EventStore, [])
    ]

    opts = [strategy: :one_for_one, name: Main.Supervisor]
    res = Supervisor.start_link(children, opts)

    Cqrex.MessageBus.subscribe(Cqrex.EventStore, [:events])

    IO.inspect Cart.new
    |> Cart.create!(Cqrex.make_uuid)
    |> Cart.add_item!("Bike")
    |> Cart.add_item!("Orange")
    |> Cqrex.AggregateRoot.save!

    res
  end

end

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
