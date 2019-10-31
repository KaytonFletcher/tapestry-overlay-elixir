defmodule Tapestry.Peer do
  use GenServer
  alias Tapestry.Math
  alias Tapestry.Manager
  alias Tapestry.Peer
  import Tapestry.Peer.Addition
  import Tapestry.Peer.Messaging

  defstruct neighbors: %{}, id: nil, root: nil, backpointers: %{}

  def create_node_from_root(id, current_id) do
    start_link(id, {self(), current_id})
  end

  def start_link(id) do
    GenServer.start_link(__MODULE__, %Peer{id: id}, [])
  end

  def start_link(id, root) do
    GenServer.start_link(__MODULE__, %Peer{id: id, root: root}, [])
  end

  @impl GenServer
  def init(st) do
    root = Map.get(st, :root)

    # if there is no root, the node is the first in the system
    if(root) do
      # #IO.inspect(self(), label: "self inside init()")
      Process.send_after(self(), :gen_route_table, 0)
    end

    {:ok, st}
  end

  @impl GenServer
  def handle_info(:gen_route_table, %Peer{id: id, root: {root, root_id}}) do
    lv =
      root_id
      |> Math.get_level(id)

    need_to_know = GenServer.call(root, {:get_need_to_know, lv, self(), id})

    need_to_know = Enum.uniq(need_to_know)

    bp =
      for {pid, nbr_id} <- need_to_know, into: %{} do
        lv = Math.get_level(nbr_id, id)
        rem = Math.rem_at_level(lv, nbr_id)
        {{lv, rem}, {pid, nbr_id}}
      end

    need_to_know = traverse_backpointers(need_to_know, lv)

    Enum.each(need_to_know, fn {pid, _nbr_id} ->
      GenServer.cast(pid, {:update_backptr, self(), id})
    end)

    # IO.inspect(need_to_know, label: "need to know nodes in gen_table")

    nbrs =
      for {pid, nbr_id} <- need_to_know, into: %{} do
        lv = Math.get_level(nbr_id, id)
        rem = Math.rem_at_level(lv, nbr_id)
        {{lv, rem}, {pid, nbr_id}}
      end

    # Enum.each(need_to_know, fn pid ->
    #   GenServer.cast(pid, {:add_nbr, self(), id})
    # end)

    # IO.inspect(nbrs, label: "starting neighborhood")

    Manager.add_node(self(), id)
    {:noreply, %Peer{id: id, neighbors: nbrs, backpointers: bp}}
  end

  @impl GenServer
  def handle_call(:get_id, _from, st) do
    {:reply, Map.get(st, :id), st}
  end

  @impl GenServer
  def handle_call({:get_bp_level, lv}, _from, st) do
    bp = Math.get_bp_at_lv(Map.get(st, :backpointers), lv)

    # IO.inspect(bp)
    {:reply, bp, st}
  end

  @impl GenServer
  def handle_call({:get_need_to_know, lv, new_pid, new_pid_id}, _from, st) do
    nbrs = get_need_to_know(lv, Map.get(st, :id), Map.get(st, :neighbors), new_pid, new_pid_id)
    new_table = add_node_to_table(st, new_pid, new_pid_id)

    {:reply, nbrs, Map.update(st, :neighbors, %{}, fn _x -> new_table end)}
  end

  @impl GenServer
  def handle_cast({:update_nbrs, nbrs}, st) do
    {:noreply, Map.update!(st, :neighbors, fn n -> Map.merge(n, nbrs) end)}
  end

  @impl GenServer
  def handle_cast({:add_nbr, pid, id}, st) do
    new_nbrs = add_node_to_table(st, pid, id)
    {:noreply, Map.update!(st, :neighbors, fn _n -> new_nbrs end)}
  end

  @impl GenServer
  def handle_cast({:update_backptr, pid, id}, st) do
    lv = Math.get_level(id, Map.get(st, :id))
    rem = Math.rem_at_level(lv, id)

    {:noreply, Map.update!(st, :backpointers, fn bp -> Map.put(bp, {lv, rem}, {pid, id}) end)}
  end

  @impl GenServer
  def handle_cast({:start_requests, id}, st) do
    current_id = Map.get(st, :id)

    lv = Math.get_level(id, current_id)
    # IO.puts("going from #{current_id} to #{id} starting at level #{lv}")
    find_reciever(id, lv, Map.get(st, :neighbors), current_id, 1)
    {:noreply, st}
  end

  @impl GenServer
  def handle_cast({:send_message, id, lv, hops}, st) do
    find_reciever(id, lv, Map.get(st, :neighbors), Map.get(st, :id), hops)
    {:noreply, st}
  end

  @impl GenServer
  def handle_cast({:next_hop, id}, st) do
    # #IO.puts("NEXT HOP WITHOUT LEVEL")
    lv = Math.get_level(id, Map.get(st, :id))
    next_hop(lv, id, Map.get(st, :neighbors), Map.get(st, :id))
    {:noreply, st}
  end

  @impl GenServer
  def handle_cast({:next_hop, lv, id}, st) do
    # #IO.inspect(lv, label: "NEXT HOP WITH LEVEL")
    next_hop(lv, id, Map.get(st, :neighbors), Map.get(st, :id))
    {:noreply, st}
  end
end
