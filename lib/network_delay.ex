defmodule NetworkDelay do
  @moduledoc """
  Documentation for NetworkDelay.
  """

  @source A
  @dest D

  @edges [
    {A, B, 5},
    {A, C, 1},
    {B, C, 1},
    {B, D, 1},
    {C, D, 3}
  ]

  @delay_factor 100

  def edges, do: @edges

  def get_routes do
    %{received_messages: [%{at: start_time}]} = :sys.get_state(@source)

    @dest
    |> :sys.get_state()
    |> Map.get(:received_messages)
    |> Enum.map(fn %{at: end_time, msg: {:ping, _, _, route}} ->
      time = NaiveDateTime.diff(end_time, start_time, :millisecond)
      %{route: Enum.reverse(route), time: time}
    end)
  end

  @spec config_from_edges(edges :: list({source :: atom(), dest :: atom(), delay :: integer()})) ::
          list(name: atom(), neighbors: list({atom, integer()}))
  def config_from_edges(edges) do
    edges
    |> group_edges(@delay_factor)
    |> Enum.map(fn {source, edges} ->
      [name: source, neighbors: edges]
    end)
  end

  def reset do
    @edges
    |> config_from_edges()
    |> Enum.each(fn config ->
      :ok =
        config
        |> Keyword.get(:name)
        |> GenServer.call(:reset)
    end)
  end

  def render_uml(filename \\ "file.uml") do
    node_specs =
      @edges
      |> Enum.map(fn {source, dest, delay} ->
        """
        #{Macro.to_string(source)} --> #{Macro.to_string(dest)}: #{delay}
        #{Macro.to_string(dest)} --> #{Macro.to_string(source)}: #{delay}
        """
      end)
      |> Enum.join("\n")

    rendered = """
    @startuml
    [*] -> #{Macro.to_string(@source)}

    #{node_specs}

    #{Macro.to_string(@dest)} -> [*]
    @enduml
    """

    :network_delay
    |> :code.priv_dir()
    |> Path.join(filename)
    |> File.write!(rendered)
  end

  def trace do
    reset()
    send(@source, {:trace, @dest})
  end

  defp group_edges(edges, delay_factor) do
    Enum.reduce(edges, %{}, fn {source, dest, delay}, acc ->
      acc
      |> put_edge(source, dest, delay * delay_factor)
      |> put_edge(dest, source, delay * delay_factor)
    end)
  end

  defp put_edge(acc, x, y, delay) do
    x_edges = Map.get(acc, x, [])

    x_edges =
      if Keyword.has_key?(x_edges, y) do
        x_edges
      else
        Keyword.put(x_edges, y, delay)
      end

    Map.put(acc, x, x_edges)
  end
end
