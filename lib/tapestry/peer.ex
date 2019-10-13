
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

  defp next_hop(lv, id) do
    if(lv == @id_length) do
      self()
    else
      d = rem(Float.floor(id/:math.pow(10, lv)), 10)
      IO.inspect(d, label: "Remainder at lv")

    end
  end

  defp find_peer_at_level(lv, current_id, current_neighbors) do


  end

  defp find_peer_at_level(lv) do
    find_peer_at_level(lv, nil)
  end



  def handle_call(:get_neighbors, state) do
    {:reply, state, state}
  end
 end

