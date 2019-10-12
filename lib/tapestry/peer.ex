
defmodule Tapestry.Peer do
  use GenServer
  defmodule PeerData do
    defstruct neighbors: %{}, id: nil
  end

  def start_link(string_hash) do
    <<_::216, id::40>> = :crypto.hash(:sha256, string_hash)
    GenServer.start_link(__MODULE__, %PeerData{id: id}, [])
  end

  def init(state) do
    IO.inspect(state)
   # Process.send_after(self(), :find_neighbors,, opts \\ [])
    {:ok, state}
  end
end

