defmodule NetworkDelay.Application do
  use Application

  alias NetworkDelay.Node

  @edges [
    [name: A, neighbors: [B, C]],
    [name: B, neighbors: [A, C, D]],
    [name: C, neighbors: [A, D]],
    [name: D, neighbors: [B, C]]
  ]

  def start(_type, _args) do
    nodes =
      Enum.map(@edges, fn config -> Supervisor.child_spec({Node, config}, id: config[:name]) end)

    children = nodes

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
