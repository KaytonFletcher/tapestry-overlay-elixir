
defmodule Tapestry.Peer do
  use GenServer

  defstruct neighbors: %{}, id: nil, root: nil

  @base 16
  @id_length 40

  def start_link(id) do
    GenServer.start_link(__MODULE__, %Tapestry.Peer{id: id}, [])
  end

  def init(st) do
    IO.inspect(st)
    if(Map.get(st, :root)) do
      Process.send_after(self(), {:find_root, Map.get(st, :root)}, 0)
    end

    {:ok, st}
  end


  def handle_cast({:next_hop, id}, st) do
    IO.puts("NEXT HOP WITHOUT LEVEL")
    lv = Tapestry.Helpers.get_level(id, Map.get(st, :id))
    next_hop(lv, id, Map.get(st, :neighbors))
  end

  def handle_cast({:next_hop, lv, id}, st) do
    IO.inspect(lv, label: "NEXT HOP WITH LEVEL")
    next_hop(lv, id, Map.get(st, :neighbors))
  end

  defp next_hop(lv, id, neighbors) do
    # if we have gone through all 40 levels, we know we are at root
    if(lv == @id_length) do
      # publish node or object with id = id
    else
      r = rem(div(id, trunc(:math.pow(10, lv))), 10)
      pid = find_peer_at_level(lv, r, neighbors)

      # if find_peer_at_level returns the pid that called the function, no neighbors to hop to
      if(pid === self()) do
        # publish node or object with id = id
      else
        Tapestry.Manager.hop()
        GenServer.cast(pid, {:next_hop, lv+1, id})
      end
    end
  end

  defp find_peer_at_level(lv, r, neighbors, @base) do
    self()
  end

  defp find_peer_at_level(lv, r, neighbors, count) do
    peer = Map.get(neighbors, {lv,r})
    if(peer) do
      peer
    else
      find_peer_at_level(lv, rem(r+1, @base), neighbors, count+1)
    end
  end

  defp find_peer_at_level(lv, r, neighbors) do
    find_peer_at_level(lv, r, neighbors, 0)
  end

  def handle_call(:get_neighbors, state) do
    {:reply, state, state}
  end
 end

