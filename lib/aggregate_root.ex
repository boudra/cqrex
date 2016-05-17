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
