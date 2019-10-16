defmodule Tapestry.Manager do
  use GenServer
  @me __MODULE__

  # MANAGER CREATION FUNCTIONS

  def start_link({nodes, requests}) do
    GenServer.start_link(__MODULE__, {nodes, requests, 0, %{}}, name: @me)
  end

  @impl GenServer
  def init(st) do
    Process.send_after(self(), :spawn_nodes, 0)
    {:ok, st}
  end

  # API

  def hop() do
    GenServer.call(@me, :hop)
  end


  # Server

  @impl GenServer
  def handle_call(:hop, _from, {nodes, reqs, hops, reqs_per_node}) do
    {:reply, :ok, {nodes, reqs, hops+1, reqs_per_node}}
  end

  @impl GenServer
  def handle_info(:spawn_nodes, {nodes, _reqs, _hops, reqs_per_node} = st) do

    {:ok, pid} = Tapestry.Peer.start_link("node1")
    mp = Map.put(reqs_per_node, pid, 0)

    for index <- 2..nodes, into: mp do
      {:ok, pid} = Tapestry.Peer.start_link("node1")
    end


    {:stop, :normal, nil}
  end

  @impl GenServer
  def handle_info(:kill, _st) do
    System.halt(0)
    {:stop, :normal, nil}
  end

  defp spawn_peers(num_nodes) do
    if(num_nodes > 0) do
      Tapestry.Peer.start_link("node#{num_nodes}")
      spawn_peers(num_nodes-1)
    end
  end
end
