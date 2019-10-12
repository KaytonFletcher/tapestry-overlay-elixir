
defmodule Tapestry.Peer do
  use GenServer

  defstruct neighbors: %{}, id: nil

  def start_link(string_hash) do
    <<_::216, id::40>> = :crypto.hash(:sha256, string_hash)
    GenServer.start_link(__MODULE__, %Tapestry.Peer{id: id}, [])
  end

  def init(state) do
    IO.inspect(state)
   # Process.send_after(self(), :find_neighbors,, opts \\ [])
    {:ok, state}
  end
end

