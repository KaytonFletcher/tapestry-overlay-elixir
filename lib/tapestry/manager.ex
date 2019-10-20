defmodule Tapestry.Manager do
  use GenServer
  @me __MODULE__

  # MANAGER CREATION FUNCTIONS

  def start_link({nodes, requests}) do
    GenServer.start_link(__MODULE__, {nodes, requests, 0, %{}}, name: @me)
  end

  @impl GenServer
  def init(st) do
    IO.inspect(self(), label: "manager pid")
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
    {:noreply, {nodes, reqs, hops + 1, reqs_per_node}}
  end

  @impl GenServer
  def handle_cast({:req_made, pid}, {nodes, reqs, hops, reqs_per_node}) do
    {:noreply, {nodes, reqs, hops, Map.update(reqs_per_node, pid, 1, fn val -> val + 1 end)}}
  end

  @impl GenServer
  def handle_cast({:add_node, pid}, {nodes, reqs, hops, mp}) do
    {:noreply, {nodes, reqs, hops, Map.put(mp, pid, 0)}}
  end

  @impl GenServer
  def handle_info(:spawn_nodes, {nodes, reqs, hops, mp}) when mp == %{}  do
    {:ok, pid} = Tapestry.Peer.start_link(Tapestry.Helpers.generate_id("node#{nodes}"))
    mp = Map.put(%{}, pid, 0)
    Process.send_after(self(), :spawn_nodes, 30)
    {:noreply, {nodes-1, reqs, hops, mp}}
  end

  @impl GenServer
  def handle_info(:spawn_nodes, {nodes, reqs, hops, node_req_map}) do
    IO.inspect(node_req_map, label: "spawning node from these")
    if(nodes > 0) do
      # generates random id using sha256 for each node
      id = Tapestry.Helpers.generate_id("node#{nodes}")

      # tells random peer to publish new peer
      {pid, _reqs} = Enum.random(node_req_map)
      GenServer.cast(pid, {:next_hop, id})
      Process.send_after(self(), :spawn_nodes, 30)
    end
    {:noreply, {nodes-1, reqs, hops, node_req_map}}
  end
end
