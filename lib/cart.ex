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

    res
  end

end
