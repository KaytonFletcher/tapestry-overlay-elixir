
defmodule Tapestry.Peer do
  use GenServer

  defstruct neighbors: %{}, id: nil, root: nil

  @base 16
  @id_length 40
  @total_bits 256

  def start_link(string_hash, start) do
    <<_::216, id::40>> = :crypto.hash(:sha256, string_hash)
    GenServer.start_link(__MODULE__, %Tapestry.Peer{id: id, root: start}, [])
  end

  def start_link(string_hash) do
    <<_::216, id::40>> = :crypto.hash(:sha256, string_hash)
    GenServer.start_link(__MODULE__, %Tapestry.Peer{id: id}, [])
  end

  def init(st) do
    IO.inspect(st)
    if(Map.get(st, :root)) do
      Process.send_after(self(), {:find_root, Map.get(st, :root)}, 0)
    end

    {:ok, st}
  end

  def handle_info({:find_root, start_pid}, st) do
    %Tapestry.Peer{id: id, neighbors: neighbors} = GenServer.call(start_pid, :get_neighbors)
    lv = Tapestry.Helpers.get_level(id, Map.get(st, :id))

    Enum.each(0..15, fn pg ->
      pid = Map.get(neighbors, {lv, pg})
      if(pid) do

      end
    end)
  end

  def next_hop(lv, id, neighbors) do
    if(lv == @id_length) do
      self()
    else
      r = rem(div(id, trunc(:math.pow(10, lv))), 10)
      find
    end
  end


  defp find_peer_at_level(lv, r, neighbors, 16) do
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

