defmodule NetworkDelay.Node do
  @moduledoc """
  GenServer that re-routes messages received to its neighbors, to simulate a routing network.

  A `NetworkDelay.Node` can also be the starting point or the exit point.
  In the case of the exit point, statistics will be saved in memory.
  """

  use GenServer

  require Logger

  def start_link(args \\ [name: __MODULE__]),
    do: GenServer.start_link(__MODULE__, args, name: args[:name])

  def init(args) do
    name =
      Keyword.get(args, :name) || raise "':name' must be  given to #{Macro.to_string(__MODULE__)}"

    neighbors = Keyword.get(args, :neighbors, [])

    {:ok, %{name: name, neighbors: neighbors, received_messages: [], audited: []}}
  end

  def handle_call(:reset, _caller, %{name: name, neighbors: neighbors}),
    do: {:reply, :ok, %{name: name, neighbors: neighbors, received_messages: [], audited: []}}

  def handle_info({:trace, dest} = msg, %{name: name, neighbors: neighbors} = state) do
    state = audit_msg(state, msg)

    Enum.each(neighbors, fn {neighbor, delay_ms} ->
      Process.send_after(neighbor, {:ping, name, dest, [name]}, delay_ms)
    end)

    msgs = Map.get(state, :received_messages, [])

    new_state =
      Map.put(state, :received_messages, [
        %{msg: {:trace, [name]}, at: NaiveDateTime.utc_now()} | msgs
      ])

    {:noreply, new_state}
  end

  def handle_info({:ping, source, dest, route} = msg, %{name: dest} = state) do
    # case for when current not is destination
    Logger.info("Trace reached destination")
    state = audit_msg(state, msg)

    msgs = Map.get(state, :received_messages, [])

    new_state =
      case Enum.at(msgs, 0) do
        {:ping, _, dest, [dest | _]} ->
          state

        _ ->
          Map.put(state, :received_messages, [
            %{msg: {:ping, source, dest, [dest | route]}, at: NaiveDateTime.utc_now()} | msgs
          ])
      end

    {:noreply, new_state}
  end

  def handle_info({:ping, source, dest, route} = msg, %{name: name, neighbors: neighbors} = state) do
    state = audit_msg(state, msg)

    Enum.each(neighbors, fn {neighbor, delay_ms} ->
      unless neighbor == source or neighbor in route do
        Process.send_after(neighbor, {:ping, name, dest, [name | route]}, delay_ms)
      else
        Logger.error("""
        Ignored message:
          #{inspect({neighbor, delay_ms})}
        process:
          #{inspect(name)}
        """)
      end
    end)

    msgs = Map.get(state, :received_messages, [])

    new_state =
      Map.put(state, :received_messages, [
        %{msg: {:ping, source, dest, [name | route]}, at: NaiveDateTime.utc_now()} | msgs
      ])

    {:noreply, new_state}
  end

  defp audit_msg(state, msg) do
    audited = Map.get(state, :audited, [])
    Map.put(state, :audited, [msg | audited])
  end
end
