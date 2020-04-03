defmodule NetworkDelay.Node do
  @moduledoc """
  GenServer that re-routes messages received to its neighbors, to simulate a routing network.

  A `NetworkDelay.Node` can also be the starting point or the exit point.
  In the case of the exit point, statistics will be saved in memory.
  """

  use GenServer

  def start_link(args \\ [name: __MODULE__]),
    do: GenServer.start_link(__MODULE__, args, name: args[:name])

  def init(args) do
    name =
      Keyword.get(args, :name) || raise "':name' must be  given to #{Macro.to_string(__MODULE__)}"

    neighbors = Keyword.get(args, :neighbors, [])

    {:ok, %{name: name, neighbors: neighbors}}
  end

  def handle_info({:trace, dest}, %{name: name, neighbors: neighbors} = state) do
    Enum.each(neighbors, fn neighbor ->
      send(neighbor, {:ping, nil, dest, [name]})
    end)

    msgs = Map.get(state, :received_messages, [])
    new_state = Map.put(state, :received_messages, [{:trace, [name]} | msgs])
    {:noreply, new_state}
  end

  def handle_info({:ping, source, dest, route}, %{name: dest} = state) do
    msgs = Map.get(state, :received_messages, [])

    new_state =
      case Enum.at(msgs, 0) do
        {:ping, _, dest, [dest | _]} ->
          state

        _ ->
          Map.put(state, :received_messages, [{:ping, source, dest, [dest | route]} | msgs])
      end

    {:noreply, new_state}
  end

  def handle_info({:ping, source, dest, route}, %{name: name, neighbors: neighbors} = state) do
    Enum.each(neighbors, fn neighbor ->
      unless neighbor == source or neighbor in route do
        send(neighbor, {:ping, name, dest, [name | route]})
      end
    end)

    msgs = Map.get(state, :received_messages, [])
    new_state = Map.put(state, :received_messages, [{:ping, source, dest, [name | route]} | msgs])
    {:noreply, new_state}
  end
end
