defmodule Cqrex.EventStore do

  use GenServer

  def handle_cast({ :events, event }, %{ events: events }) do
    {:noreply, %{ events: [ event | events ] }}
  end

  def handle_call(:get_events, _from, state) do
    {:reply, state.events, state}
  end

  def get_events() do
    GenServer.call(__MODULE__, :get_events)
  end

  def start_link do
    {:ok, pid} = GenServer.start_link(__MODULE__, nil, name: __MODULE__)
    Cqrex.MessageBus.subscribe(pid, [:events])
    {:ok, pid}
  end

  def init(_args) do
    { :ok, %{ events: [] } }
  end

end
