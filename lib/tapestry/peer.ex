defmodule Tapestry.Peer do
  use GenServer

  defstruct neighbors: %{}, id: nil, root: nil

  @base 16
  @id_length 40

  def start_link(id) do
    GenServer.start_link(__MODULE__, %Tapestry.Peer{id: id}, [])
  end

  def start_link(id, root) do
    GenServer.start_link(__MODULE__, %Tapestry.Peer{id: id, root: root}, [])
  end

  def init(st) do
    IO.inspect(st)

    root = Map.get(st, :root)

    if(root) do
      IO.inspect(self(), label: "self inside init()")
      Process.send_after(self(), :gen_table, 0)
    end

    {:ok, st}
  end

  def handle_info(:gen_table, %Tapestry.Peer{id: id, root: root}) do
    need_to_know = GenServer.call(root, {:add_node, {id, self()}})

    IO.inspect(need_to_know, label: "need to know nodes in gen_table")

    nbrs =
      for {pid, nbr_id} <- need_to_know, into: %{} do
        lv = Tapestry.Helpers.get_level(id, nbr_id)
        rem = rem_at_level(lv, nbr_id)
        {{lv, rem}, {pid, id}}
      end

    IO.inspect(nbrs, label: "starting neighborhood")

    Tapestry.Manager.add_node(self())
    {:noreply, %Tapestry.Peer{id: id, neighbors: nbrs}}
  end

  def handle_call({:add_node, {id, pid}}, _from, st) do
    IO.puts("Adding node")
    current_id = Map.get(st, :id)
    lv = Tapestry.Helpers.get_level(id, current_id)

    neighbors_at_lv =
      Map.get(st, :neighbors)
      |> Tapestry.Helpers.get_neighbors_at_lv(lv)

    IO.inspect(neighbors_at_lv, label: "Getting next neigbors")

    next_neighbors =
      for nbr <- neighbors_at_lv do
        GenServer.call(nbr, {:add_node, {id, pid}})
      end

    IO.puts("adding node to table")
    map = add_node_to_table({Map.get(st, :id), Map.get(st, :neighbors)}, {id, pid})

    {:reply, [{self(), current_id}] ++ neighbors_at_lv ++ next_neighbors,
     Map.update(st, :neighbors, %{}, fn _x -> map end)}
  end

  def handle_cast({:next_hop, id}, st) do
    IO.puts("NEXT HOP WITHOUT LEVEL")
    lv = Tapestry.Helpers.get_level(id, Map.get(st, :id))
    next_hop(lv, id, Map.get(st, :neighbors))
    {:noreply, st}
  end

  def handle_cast({:next_hop, lv, id}, st) do
    IO.inspect(lv, label: "NEXT HOP WITH LEVEL")
    next_hop(lv, id, Map.get(st, :neighbors))
    {:noreply, st}
  end

  defp next_hop(lv, id, neighbors) do
    # if we have gone through all 40 levels, we know we are at root
    if(lv == @id_length) do
      # publish node with id = id
      add_node(id)
    else
      r = rem_at_level(lv, id)
      pid = find_peer_at_level(lv, r, neighbors)

      # if find_peer_at_level returns the pid that called the function, no neighbors to hop to
      if(pid === self()) do
        # publish node with id = id
        add_node(id)
      else
        GenServer.cast(pid, {:next_hop, lv + 1, id})
      end
    end
  end

  def add_node(id) do
    start_link(id, self())
  end

  defp add_node_to_table({id1, neighbors}, {id2, pid}) do
    lv = Tapestry.Helpers.get_level(id1, id2)
    r = rem_at_level(lv, id2)
    Map.put(neighbors, {lv, r}, {pid, id2})
  end

  defp rem_at_level(lv, id) do
    rem(div(id, trunc(:math.pow(10, lv))), 10)
  end

  defp find_peer_at_level(_lv, _r, _neighbors, @base) do
    self()
  end

  defp find_peer_at_level(lv, r, neighbors, count) do
    case Map.get(neighbors, {lv, r}) do
      nil -> find_peer_at_level(lv, rem(r + 1, @base), neighbors, count + 1)
      {pid, _id} -> pid
    end
  end

  defp find_peer_at_level(lv, r, neighbors) do
    find_peer_at_level(lv, r, neighbors, 0)
  end

  def handle_call(:get_neighbors, state) do
    {:reply, state, state}
  end
end
