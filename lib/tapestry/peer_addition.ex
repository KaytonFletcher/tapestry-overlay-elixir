defmodule Tapestry.Peer.Addition do
  alias Tapestry.Math
  @id_length 16
  @base 16

  def get_need_to_know(lv, neighbors, new_pid, new_pid_id) do
    # #IO.inspect( Map.get(st, :neighbors))
    if(lv < @base && lv >= 0) do
      neighbors_at_lv =
        neighbors
        |> Math.get_neighbors_at_lv(lv)
        |> Enum.uniq()

      ## IO.inspect(neighbors_at_lv, label: "NEIGHBORS AT LEVEL")

      more =
        get_need_to_know(lv + 1, neighbors, new_pid, new_pid_id)
        |> Enum.uniq()

      # IO.inspect(more, label: "MORE")

      next_neighbors =
        Enum.flat_map(neighbors_at_lv, fn nbr ->
          GenServer.call(nbr, {:get_need_to_know, lv + 1, new_pid, new_pid_id})
        end)
        |> Enum.uniq()

      ## IO.inspect(next_neighbors, label: "NEXT NEIGHBORS")
      ([self()] ++ more ++ neighbors_at_lv ++ next_neighbors) |> Enum.uniq()
    else
      []
    end
  end

  def traverse_backpointers(neighbors, lv) do
    if(lv >= 0) do
      # IO.puts("Traversing bps at level #{lv}")
      nextNeighbors = neighbors |> Enum.uniq()

      bp =
        Enum.flat_map(neighbors, fn pid ->
          GenServer.call(pid, {:get_bp_level, lv})
        end)
        |> Enum.uniq()

      ## IO.inspect(bp, label: "bp outside")
      ## IO.inspect(bp ++ nextNeighbors)

      traverse_backpointers(bp ++ nextNeighbors, lv - 1)
    else
      neighbors
    end
  end

  def next_hop(lv, id, neighbors) do
    # if we have gone through all levels, we know we are at root
    if(lv === @id_length) do
      # publish node with id = id, we are at surrogate root
      Tapestry.Peer.create_node_from_root(id)
    else
      r = Math.rem_at_level(lv, id)
      pid = Math.find_peer_at_level(lv, r, neighbors)

      # #IO.inspect(pid, label: "node at level #{lv}")

      # if find_peer_at_level returns the pid that called the function, no neighbors to hop to
      if(pid === self()) do
        # publish node with id = id, we are at surrogate root
        # create_node_from_root(id)
        next_hop(lv + 1, id, neighbors)
      else
        GenServer.cast(pid, {:next_hop, lv + 1, id})
      end
    end
  end

  def add_node_to_table(%{neighbors: n, id: id}, new_pid, id_to_add) do
    lv = Math.get_level(id, id_to_add)
    rem = Math.rem_at_level(lv, id_to_add)
    pid = Map.get(n, {lv, rem})

    if(pid) do
      id2 = GenServer.call(pid, :get_id)
      # IO.inspect("CONFLICT")

      if(Math.is_closer?(id, id2, id_to_add)) do
        Map.put(n, {lv, rem}, new_pid)
      else
        n
      end
    else
      Map.put(n, {lv, rem}, new_pid)
    end
  end
end
