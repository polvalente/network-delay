defmodule NetworkDelay.Application do
  use Application

  alias NetworkDelay.Node

  # A <-5-> B
  # A <-1-> C
  # C <-1-> B
  # C <-3-> D
  # B <-1-> D

  # Best route from A to D: A -> C -> B -> D = 3
  # Other routes:
  #  A -> B -> D = 6
  #  A -> C -> D = 1 + 3 = 4
  # Worst route from A to D: A -> B -> C -> D = 9

  def start(_type, _args) do
    nodes =
      NetworkDelay.edges()
      |> NetworkDelay.config_from_edges()
      |> Enum.map(fn config -> Supervisor.child_spec({Node, config}, id: config[:name]) end)

    children = nodes

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
