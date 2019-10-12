defmodule Tapestry.Collector do
  use GenServer
  @me Tapestry.Collecter

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: @me)
  end

  @impl GenServer
  def init(st) do
    Process.send_after(self(), :kill, 2000)
    {:ok, st}
  end

  @impl GenServer
  def handle_info(:kill, _st) do
    System.halt(0)
    {:stop, :normal, nil}
  end
end
