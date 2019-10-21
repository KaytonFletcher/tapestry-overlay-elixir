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

  def add_node(pid, id) do
    IO.puts("adding node")
    GenServer.cast(@me, {:add_node, {pid, id}})
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
  def handle_cast({:add_node, {pid, id}}, {nodes, reqs, hops, mp}) do
    {:noreply, {nodes, reqs, hops, Map.put(mp, {pid, id}, 0)}}
  end

  @impl GenServer
  def handle_info(:send_requests, {_nodes, _reqs, _hops, mp}) when mp == %{} do
    System.halt(0)
  end

  @impl GenServer
  def handle_info(:send_requests, {nodes, reqs, hops, mp}) do
    Enum.each(mp, fn {{req, id1}, _reqs} ->
      {{_rec, id2}, _reqs} =
        Map.delete(mp, {req, id1})
        |> Enum.random()

      GenServer.cast(req, {:start_requests, id2})
    end)

    new_map = for {pid, req} <- mp, into: %{}, do: {pid, req + 1}

    {:noreply, {nodes, reqs, hops, new_map}}
  end

  @impl GenServer
  def handle_info(:spawn_nodes, {nodes, reqs, hops, mp}) when mp == %{} do
    id = Tapestry.Helpers.generate_id("node#{nodes}")
    {:ok, pid} = Tapestry.Peer.start_link(id)
    mp = Map.put(%{}, {pid, id}, 0)
    Process.send_after(self(), :spawn_nodes, 30)
    {:noreply, {nodes - 1, reqs, hops, mp}}
  end

  @impl GenServer
  def handle_info(:spawn_nodes, {nodes, reqs, hops, node_req_map}) do
    IO.inspect(node_req_map, label: "spawning node from these")

    if(nodes > 0) do
      # generates random id using sha256 for each node
      id = Tapestry.Helpers.generate_id("node#{nodes}")

      # tells random peer to publish new peer
      {{pid, _id}, _reqs} = Enum.random(node_req_map)
      GenServer.cast(pid, {:next_hop, id})
      Process.send_after(self(), :spawn_nodes, 40)
    else
      Process.send_after(self(), :send_requests, 40)
    end

    {:noreply, {nodes - 1, reqs, hops, node_req_map}}
  end
end
