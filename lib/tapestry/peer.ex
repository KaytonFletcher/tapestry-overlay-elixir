defmodule Tapestry.Peer do
  use GenServer
  alias Tapestry.Helpers
  alias Tapestry.Manager
  alias Tapestry.Peer

  defstruct neighbors: %{}, id: nil, root: nil, backpointers: %{}

  @base 16
  @id_length 16

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
      # IO.inspect(self(), label: "self inside init()")
      Process.send_after(self(), :gen_route_table, 0)
    end

    {:ok, st}
  end

  @impl GenServer
  def handle_info(:gen_route_table, %Peer{id: id, root: root}) do
    lv =
      GenServer.call(root, :get_id)
      |> Helpers.get_level(id)

    need_to_know = GenServer.call(root, {:get_need_to_know, lv, self(), id})

    need_to_know = Enum.uniq(need_to_know)

    bp =
      for pid <- need_to_know, into: %{} do
        nbr_id = GenServer.call(pid, :get_id)
        lv = Helpers.get_level(nbr_id, id)
        rem = Helpers.rem_at_level(lv, nbr_id)
        {{lv, rem}, pid}
      end

    IO.inspect(bp, label: "backpointer list")

    need_to_know = traverse_backpointers(need_to_know, lv)

    Enum.each(need_to_know, fn pid ->
      GenServer.cast(pid, {:update_backptr, self(), id})
    end)

    IO.inspect(need_to_know, label: "need to know nodes in gen_table")

    nbrs =
      for pid <- need_to_know, into: %{} do
        nbr_id = GenServer.call(pid, :get_id)
        lv = Helpers.get_level(nbr_id, id)
        rem = Helpers.rem_at_level(lv, nbr_id)
        {{lv, rem}, pid}
      end

    # Enum.each(need_to_know, fn pid ->
    #   GenServer.cast(pid, {:add_nbr, self(), id})
    # end)

    IO.inspect(nbrs, label: "starting neighborhood")

    Manager.add_node(self(), id)
    {:noreply, %Peer{id: id, neighbors: nbrs, backpointers: bp}}
  end

  defp traverse_backpointers(neighbors, lv) do
    if(lv >= 0) do
      IO.puts("Traversing bps at level #{lv}")
      nextNeighbors = neighbors

      bp =
        Enum.flat_map(neighbors, fn pid ->
          GenServer.call(pid, {:get_bp_level, lv})
        end)

      IO.inspect(bp, label: "bp outside")
      IO.inspect(bp ++ nextNeighbors)

      traverse_backpointers(bp ++ nextNeighbors, lv - 1)
    else
      neighbors
    end
  end

  @impl GenServer
  def handle_call(:get_id, _from, st) do
    {:reply, Map.get(st, :id), st}
  end

  @impl GenServer
  def handle_call({:get_bp_level, lv}, _from, st) do
    bp = Helpers.get_bp_at_lv(Map.get(st, :backpointers), lv)

    IO.inspect(bp)
    {:reply, bp, st}
  end

  @impl GenServer
  def handle_call({:get_need_to_know, lv, new_pid, new_pid_id}, _from, st) do
    # IO.inspect(lv, label: "get_need_to_know at level")

    # IO.inspect( Map.get(st, :neighbors))

    neighbors_at_lv =
      Map.get(st, :neighbors)
      |> Helpers.get_neighbors_at_lv(lv)

    # IO.inspect(neighbors_at_lv, label: "Getting next neigbors")

    next_neighbors =
      Enum.flat_map(neighbors_at_lv, fn nbr ->
        GenServer.call(nbr, {:get_need_to_know, lv + 1, new_pid, new_pid_id})
      end)

    new_table = add_node_to_table(st, new_pid, new_pid_id)
    # IO.inspect(new_table, label: "NEW TABLE")

    {:reply, [self()] ++ neighbors_at_lv ++ next_neighbors,
     Map.update(st, :neighbors, %{}, fn _x -> new_table end)}
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
    lv = Helpers.get_level(id, Map.get(st, :id))
    rem = Helpers.rem_at_level(lv, id)

    {:noreply, Map.update!(st, :backpointers, fn bp -> Map.put(bp, {lv, rem}, pid) end)}
  end

  @impl GenServer
  def handle_cast({:start_requests, id}, st) do
    current_id = Map.get(st, :id)

    lv = Helpers.get_level(id, current_id)
    IO.puts("going from #{current_id} to #{id} starting at level #{lv}")
    find_reciever(id, lv, Map.get(st, :neighbors), current_id)
    {:noreply, st}
  end

  @impl GenServer
  def handle_cast({:send_message, id, lv}, st) do
    find_reciever(id, lv, Map.get(st, :neighbors), Map.get(st, :id))
    {:noreply, st}
  end

  @impl GenServer
  def handle_cast({:next_hop, id}, st) do
    # IO.puts("NEXT HOP WITHOUT LEVEL")
    lv = Helpers.get_level(id, Map.get(st, :id))
    next_hop(lv, id, Map.get(st, :neighbors))
    {:noreply, st}
  end

  @impl GenServer
  def handle_cast({:next_hop, lv, id}, st) do
    # IO.inspect(lv, label: "NEXT HOP WITH LEVEL")
    next_hop(lv, id, Map.get(st, :neighbors))
    {:noreply, st}
  end

  defp find_reciever(id, lv, neighbors, current_id) do
    cond do
      current_id == id ->
        IO.puts("FOUND THE CORRECT ID: #{current_id}")

      lv == @id_length ->
        if(current_id === id) do
          IO.puts("FOUND THE CORRECT ID: #{current_id}")
        else
          IO.puts("NOT GOOD CHIEF #{current_id} != id to find: #{id}")
        end

      true ->
        r = Helpers.rem_at_level(lv, id)
        pid = find_peer_at_level(lv, r, neighbors)

        # if(id == 7803) do
        #   IO.inspect(pid, label: "Remainder: #{r} Level: #{lv} Current id: #{current_id}  ")
        # end
        # if(current_id == 7803) do
        #   IO.inspect(pid, label: "Remainder: #{r} Level: #{lv} Looking for id: #{id}  ")
        # end

        # if find_peer_at_level returns the pid that called the function, no neighbors to hop to
        if(pid === self()) do
          if(current_id === id) do
            IO.puts("FOUND THE CORRECT ID: #{current_id}")
          else
            IO.puts("NOT GOOD CHIEF #{current_id} != id to find: #{id}")
          end
        else
          IO.inspect(pid, label: "Hopping from #{current_id} to")
          GenServer.cast(pid, {:send_message, id, lv + 1})
        end
    end
  end

  defp next_hop(lv, id, neighbors) do
    # if we have gone through all levels, we know we are at root
    if(lv === @id_length) do
      # publish node with id = id, we are at surrogate root
      create_node_from_root(id)
    else
      r = Helpers.rem_at_level(lv, id)
      pid = find_peer_at_level(lv, r, neighbors)

      # IO.inspect(pid, label: "node at level #{lv}")

      # if find_peer_at_level returns the pid that called the function, no neighbors to hop to
      if(pid === self()) do
        # publish node with id = id, we are at surrogate root
        create_node_from_root(id)
      else
        GenServer.cast(pid, {:next_hop, lv + 1, id})
      end
    end
  end

  def create_node_from_root(id) do
    start_link(id, self())
  end

  defp add_node_to_table(%Peer{neighbors: n, id: id}, new_pid, id_to_add) do
    lv = Helpers.get_level(id, id_to_add)
    rem = Helpers.rem_at_level(lv, id_to_add)
    pid = Map.get(n, {lv, rem})

    if(pid) do
      id2 = GenServer.call(pid, :get_id)
      IO.inspect("CONFLICT")

      if(Helpers.is_closer?(id, id2, id_to_add)) do
        Map.put(n, {lv, rem}, new_pid)
      end
    else
      Map.put(n, {lv, rem}, new_pid)
    end
  end

  defp find_peer_at_level(_lv, _r, _neighbors, @base) do
    self()
  end

  defp find_peer_at_level(lv, r, neighbors, count) do
    case Map.get(neighbors, {lv, r}) do
      nil -> find_peer_at_level(lv, rem(r + 1, @base), neighbors, count + 1)
      pid -> pid
    end
  end

  defp find_peer_at_level(lv, r, neighbors) do
    find_peer_at_level(lv, r, neighbors, 0)
  end
end
