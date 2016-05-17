defmodule Cqrex do

  use Application

  defmodule AtomType do

    def type, do: :string

    def cast(atom) when is_atom(atom), do:
      {:ok, Atom.to_string(atom) }

    def cast(string) when is_binary(string), do: {:ok, string}
    def cast(_), do: :error

    def load(string) when is_binary(string), do:
      {:ok, String.to_existing_atom(string) }

    def load(_), do: :error

    def dump(value), do: cast(value)

  end

  defmodule Event do

    defstruct [
      :uuid,
      :timestamp,
      :aggregate_uuid,
      :aggregate_type,
      :type,
      :payload
    ]

  end

  def make_uuid do
    Kernel.make_ref
  end

  def timestamp do
    :erlang.system_time
  end

  def make_event(type, aggregate_type, aggregate, payload) do
    %Event{
      uuid: Cqrex.make_uuid,
      aggregate_type: aggregate_type,
      aggregate_uuid: aggregate,
      timestamp: Cqrex.timestamp,
      type: type,
      payload: payload
    }
  end


  def start(_type, _args) do

    import Supervisor.Spec, warn: false

    children = [
      worker(Cqrex.MessageBus, []),
      worker(Cqrex.EventStore, [])
    ]

    opts = [strategy: :one_for_one, name: Main.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
