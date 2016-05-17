defmodule Cqrex.MessageBus do

  def start_link, do:
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def init(:ok), do:
    {:ok, %{}}

  def handle_cast({ :subscribe, %{channel: [ ch | tail ], pid: pid} }, state) do
    new_state = state |> Map.put(ch, [ pid | Map.get(state, ch, []) ])
    handle_cast({ :subscribe, %{channel: tail, pid: pid}}, new_state)
  end

  def handle_cast({ :subscribe, %{channel: [], pid: _} }, state) do
    {:noreply, state}
  end

  def handle_cast({ :unsubsribe, %{channel: ch, pid: pid} }, state) do
    new_state = state |> Map.put(ch, List.delete(Map.get(state, ch), pid))
    {:noreply, new_state}
  end

  def handle_cast({:publish, %{channel: ch, message: message}}, state) do
    for sub <- Map.get(state, ch, []) do
      GenServer.cast(sub, { ch, message })
    end
    {:noreply, state}
  end

  def publish(channel, message) do
    GenServer.cast(__MODULE__, {:publish, %{channel: channel, message: message}})
  end

  def subscribe(pid, channel) when is_list(channel) do
    GenServer.cast(__MODULE__, {:subscribe, %{channel: channel, pid: pid}})
  end

  def subscribe(pid, channel) when is_atom(channel) do
    GenServer.cast(__MODULE__, {:subscribe, %{channel: [channel], pid: pid}})
  end

  def unsubscribe(pid, channel) do
    GenServer.cast(__MODULE__, {:subscribe, %{channel: channel, pid: pid}})
  end

end
