defmodule Tapestry.Manager do
  use GenServer
  alias Tapestry.Math

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

  ## API ##

  def add_node(pid, id) do
    GenServer.cast(@me, {:add_node, {pid, id}})
  end

  # peer sends manager number of hops it took to complete request
  def req_made(hops) do
    GenServer.cast(@me, {:req_made, self(), hops})
  end

  ## Server ##

  @impl GenServer
  def handle_cast({:req_made, pid, new_hops}, {reqs, hops, mp, start}) do
    new_mp = Map.update!(mp, pid, fn val -> val + 1 end)

    if(Map.get(mp, pid) == reqs) do
      {:noreply, {reqs, [new_hops] ++ hops, Map.delete(new_mp, pid), start}}
    else
      {:noreply, {reqs, [new_hops] ++ hops, new_mp, start}}
    end
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
  def handle_info(:send_requests, {_nodes, reqs, hops, mp}) do
    start = System.monotonic_time(:millisecond)

    Enum.each(mp, fn {{req, id1}, _reqs} ->
      {{_rec, id2}, _reqs} =
        Map.delete(mp, {req, id1})
        |> Enum.random()

      GenServer.cast(req, {:start_requests, id2})
    end)

    # at this no peers requests have completed
    new_map = for {{pid, _id}, _req} <- mp, into: %{}, do: {pid, 0}

    {:noreply, {reqs, hops, new_map, start}}
  end

  @impl GenServer
  def handle_info(:spawn_nodes, {nodes, reqs, hops, mp}) when mp == %{} do
    id = Math.generate_id("node#{nodes}")
    {:ok, pid} = Tapestry.Peer.start_link(id)
    mp = Map.put(%{}, {pid, id}, 0)
    Process.send_after(self(), :spawn_nodes, 30)
    {:noreply, {nodes - 1, reqs, hops, mp}}
  end

  @impl GenServer
  def handle_info(:spawn_nodes, {nodes, reqs, hops, node_req_map}) do
    if(nodes > 0) do
      # generates random id using sha256 for each node
      id = Math.generate_id("node#{nodes}")

      # tells random peer to publish new peer
      {{pid, _id}, _reqs} = Enum.random(node_req_map)

      # IO.inspect(pid, label: "adding node #{id} from")
      GenServer.cast(pid, {:next_hop, id})
      Process.send_after(self(), :spawn_nodes, 40)
    else
      Process.send_after(self(), :send_requests, 40)
    end

    {:noreply, {nodes - 1, reqs, hops, node_req_map}}
  end
end
