defmodule Tapestry.Manager do
  use GenServer
  @me __MODULE__

  # MANAGER CREATION FUNCTIONS

  def start_link({nodes, requests}) do
    GenServer.start_link(__MODULE__, {nodes, requests, 0, %{}}, name: @me)
  end

  @impl GenServer
  def init(st) do
    Process.send_after(self(), :spawn_nodes, 0)
    {:ok, st}
  end

  # API

  def add_node(pid) do
    GenServer.cast(@me, {:add_node, pid})
  end

  def req_made() do
    GenServer.cast(@me, {:req_made, self()})
  end

  def hop() do
    GenServer.cast(@me, :hop)
  end

  # Server

  @impl GenServer
  def handle_cast(:hop, {nodes, reqs, hops, reqs_per_node}) do
    {:reply, :ok, {nodes, reqs, hops + 1, reqs_per_node}}
  end

  @impl GenServer
  def handle_cast({:req_made, pid}, {nodes, reqs, hops, reqs_per_node}) do
    {:reply, :ok, {nodes, reqs, hops, Map.update(reqs_per_node, pid, 1, fn val -> val + 1 end)}}
  end

  @impl GenServer
  def handle_info(:spawn_nodes, {nodes, _reqs, _hops, node_req_map} = st) do
    {:ok, pid} = Tapestry.Peer.start_link("node1")
    mp = Map.put(node_req_map, pid, 0)
    spawn_peers(mp, nodes-1)
    {:reply, :ok, st}
  end



  defp spawn_peers(node_req_map, num_nodes) do
    if(num_nodes > 0) do
      # generates random id using sha256 for each node
      id = Tapestry.Helpers.generate_id("node#{num_nodes}")

      # tells random peer to publish new peer
      {pid, _reqs} = Enum.random(node_req_map)
      GenServer.cast(pid, {:next_hop, id})

      spawn_peers(node_req_map, num_nodes - 1)
    end
  end
end
