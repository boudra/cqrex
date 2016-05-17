defmodule Cqrex do

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

end


defmodule Cqrex.AggregateRoot do

  defprotocol Protocol do
    def events(aggregate)
  end

  defimpl Protocol, for: Any do
    defmacro __deriving__(module, struct, _) do
      Module.put_attribute(module, :struct, Map.put(struct, :__events__, []))
      :ok
    end
    def events(aggregate) do
      aggregate.__events__
    end
  end

  defmacro __before_compile__(_) do
    quote do
      def new() do
        unquote({:%, [], [__CALLER__.module, {:%{}, [], [ __events__: [] ]}]})
      end
    end
  end

  defmacro __using__(_opts) do
    quote do
      import Cqrex
      import Cqrex.AggregateRoot

      @before_compile Cqrex.AggregateRoot
      @derive [ Protocol ]
    end
  end

  def save!(aggregate) do
    Enum.each(
      aggregate.__events__,
      &(Cqrex.MessageBus.publish(:events, &1))
    )
    struct(aggregate, %{ __events__: [] })
  end

  def dispatch(aggregate, event, payload \\ nil ) do
    aggregate = struct(aggregate, %{
      __events__: [ Cqrex.make_event(
        event, aggregate.__struct__, aggregate.id, payload
        ) | aggregate.__events__ ]
    })
    apply_change(aggregate, event, payload)
  end

  def apply_change(aggregate, event, payload) do
    apply(aggregate.__struct__, event, [ aggregate, payload ] |> Enum.reject(&is_nil/1))
  end

end

defmodule Cqrex.EventStore do

  use GenServer

  def handle_cast({ :events, event }, %{ events: events }) do
    {:noreply, %{ events: [ event | events ] }}
  end

  def start_link do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_args) do
    { :ok, %{ events: [] } }
  end

end
