defmodule Tapestry.Peer.Messaging do
  alias Tapestry.Math
  @id_length 40

  def find_reciever(id, lv, neighbors, current_id, hops) do
    cond do
      current_id == id ->
        Tapestry.Manager.req_finished(hops)

      lv == @id_length ->
        Tapestry.Manager.req_finished(hops)


      true ->
        r = Math.rem_at_level(lv, id)
        {pid, id} = Math.find_peer_at_level(current_id, lv, r, neighbors)

        # if find_peer_at_level returns the pid that called the function, look at next level
        if(pid === self()) do
          find_reciever(id, lv + 1, neighbors, current_id, hops)
        else
          # IO.inspect(pid, label: "Hopping from #{current_id} to")
          GenServer.cast(pid, {:send_message, id, lv + 1, hops+1})
        end
    end
  end
end
