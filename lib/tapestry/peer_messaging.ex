defmodule Tapestry.Peer.Messaging do
  alias Tapestry.Math
  @id_length 16

  def find_reciever(id, lv, neighbors, current_id) do
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
        r = Math.rem_at_level(lv, id)
        pid = Math.find_peer_at_level(lv, r, neighbors)

        # if find_peer_at_level returns the pid that called the function, no neighbors to hop to
        if(pid === self()) do
          find_reciever(id, lv + 1, neighbors, current_id)
        else
          # IO.inspect(pid, label: "Hopping from #{current_id} to")
          GenServer.cast(pid, {:send_message, id, lv + 1})
        end
    end
  end
end
