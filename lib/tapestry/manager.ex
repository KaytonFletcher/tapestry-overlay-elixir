defmodule Tapestry.Manager do
  use GenServer
  alias Tapestry.Math

  @me __MODULE__

  # MANAGER CREATION FUNCTIONS

  def start_link({nodes, requests}) do
    GenServer.start_link(__MODULE__, {nodes, requests, [], %{}, nodes * requests}, name: @me)
  end

  @impl GenServer
  def init(st) do
    Process.send_after(self(), :spawn_nodes, 0)
    {:ok, st}
  end

  ## API ##

  def add_node(pid, id) do
    GenServer.cast(@me, {:add_node, {pid, id}})
  end

  def req_finished(hops) do
    GenServer.cast(@me, {:req_finished, hops})
  end

  ## Server ##

  @impl GenServer
  def handle_cast({:req_finished, new_hop}, {reqs, hops, num_hops, mp, start, total_reqs}) do
    new_hops = [new_hop] ++ hops

    if(num_hops + 1 === total_reqs) do
      Enum.max(new_hops)
      |> IO.inspect(label: "Max hops")

      #IO.inspect(System.monotonic_time(:millisecond) - start, label: "time taken to send messages")

      System.halt(0)
    end

    {:noreply, {reqs, new_hops, num_hops + 1, mp, start, total_reqs}}
  end

  @impl GenServer
  def handle_cast({:add_node, {pid, id}}, {nodes, reqs, hops, mp, total_reqs}) do
    {:noreply, {nodes, reqs, hops, Map.put(mp, {pid, id}, 0), total_reqs}}
  end

  @impl GenServer
  def handle_info(:send_requests, {reqs, hops, num_hops, mp, start, total_reqs}) do
    if(reqs > 0) do
      Enum.each(mp, fn {pid1, {_reqs, _id}} ->
        {_pid2, {_reqs, id2}} =
          Map.delete(mp, pid1)
          |> Enum.random()

        GenServer.cast(pid1, {:start_requests, id2})
      end)

      new_map = for {pid, {req, id}} <- mp, into: %{}, do: {pid, {req + 1, id}}
      Process.send_after(self(), :send_requests, 1000)
      {:noreply, {reqs - 1, hops, num_hops, new_map, start, total_reqs}}
    else
      {:noreply, {reqs, hops, num_hops, mp, start, total_reqs}}
    end
  end

  @impl GenServer
  def handle_info(:spawn_nodes, {nodes, reqs, hops, mp, total_reqs}) when mp == %{} do
    id = Math.generate_id("node#{nodes}")
    {:ok, pid} = Tapestry.Peer.start_link(id)
    mp = Map.put(%{}, {pid, id}, 0)
    Process.send_after(self(), :spawn_nodes, 30)
    {:noreply, {nodes - 1, reqs, hops, mp, total_reqs}}
  end

  @impl GenServer
  def handle_info(:spawn_nodes, {nodes, reqs, hops, node_req_map, total_reqs}) do
    if(nodes > 0) do
      # generates random id using sha256 for each node
      id = Math.generate_id("node#{nodes}")

      # tells random peer to publish new peer
      {{pid, _id}, _reqs} = Enum.random(node_req_map)

      # IO.inspect(pid, label: "adding node #{id} from")
      GenServer.cast(pid, {:next_hop, id})
      Process.send_after(self(), :spawn_nodes, 40)
      {:noreply, {nodes - 1, reqs, hops, node_req_map, total_reqs}}
    else
      nds = div(total_reqs, reqs)
      if(nds != map_size(node_req_map)) do

        Process.send_after(self(), :spawn_nodes, 50)
        {:noreply, {nodes, reqs, hops, node_req_map, total_reqs}}
      else
         # no peer has made a request
        new_map = for {{pid, id}, _req} <- node_req_map, into: %{}, do: {pid, {0, id}}
        Process.send_after(self(), :send_requests, 20)
        {:noreply, {reqs, hops, 0, new_map, System.monotonic_time(:millisecond), total_reqs}}
      end
    end
  end
end
