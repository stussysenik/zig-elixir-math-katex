defmodule MathViz.QA.CallGraph do
  @moduledoc false

  use Agent

  @type graph_node :: %{
          required(:id) => String.t(),
          required(:kind) => String.t(),
          required(:label) => String.t()
        }

  @type edge :: %{
          required(:from) => String.t(),
          required(:to) => String.t(),
          required(:kind) => String.t(),
          required(:status) => String.t(),
          required(:duration_ms) => integer(),
          required(:metadata) => map()
        }

  @type graph :: %{nodes: [graph_node()], edges: [edge()]}

  @spec start_link(keyword()) :: Agent.on_start()
  def start_link(opts \\ []) do
    Agent.start_link(fn -> %{nodes: %{}, edges: []} end, opts)
  end

  @spec record_call(pid() | nil, String.t(), String.t(), map()) :: :ok
  def record_call(pid, from, to, attrs \\ %{})

  def record_call(nil, _from, _to, _attrs), do: :ok

  def record_call(pid, from, to, attrs) do
    Agent.update(pid, fn state ->
      state
      |> put_node(from, Map.get(attrs, :from_kind, "function"), Map.get(attrs, :from_label, from))
      |> put_node(to, Map.get(attrs, :to_kind, "function"), Map.get(attrs, :to_label, to))
      |> put_edge(from, to, attrs)
    end)
  end

  @spec snapshot(pid() | nil) :: graph()
  def snapshot(nil), do: %{nodes: [], edges: []}

  def snapshot(pid) do
    Agent.get(pid, fn state ->
      %{
        nodes: state.nodes |> Map.values() |> Enum.sort_by(& &1.id),
        edges: Enum.reverse(state.edges)
      }
    end)
  end

  @spec merge([graph()]) :: graph()
  def merge(graphs) do
    Enum.reduce(graphs, %{nodes: %{}, edges: []}, fn graph, acc ->
      acc
      |> merge_nodes(Map.get(graph, :nodes, []))
      |> merge_edges(Map.get(graph, :edges, []))
    end)
    |> then(fn state ->
      %{
        nodes: state.nodes |> Map.values() |> Enum.sort_by(& &1.id),
        edges: Enum.reverse(state.edges)
      }
    end)
  end

  @spec write!(graph(), Path.t()) :: Path.t()
  def write!(graph, path) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, Jason.encode!(graph, pretty: true))
    path
  end

  defp put_node(state, id, kind, label) do
    node = %{id: id, kind: kind, label: label}
    %{state | nodes: Map.put_new(state.nodes, id, node)}
  end

  defp put_edge(state, from, to, attrs) do
    edge = %{
      from: from,
      to: to,
      kind: Map.get(attrs, :kind, "calls"),
      status: normalize_status(Map.get(attrs, :status, :ok)),
      duration_ms: Map.get(attrs, :duration_ms, 0),
      metadata: Map.get(attrs, :metadata, %{})
    }

    %{state | edges: [edge | state.edges]}
  end

  defp merge_nodes(state, nodes) do
    Enum.reduce(nodes, state, fn node, acc ->
      %{acc | nodes: Map.put_new(acc.nodes, node.id, node)}
    end)
  end

  defp merge_edges(state, edges) do
    %{state | edges: Enum.reverse(edges) ++ state.edges}
  end

  defp normalize_status(status) when is_atom(status), do: Atom.to_string(status)
  defp normalize_status(status) when is_binary(status), do: status
  defp normalize_status(_status), do: "ok"
end
