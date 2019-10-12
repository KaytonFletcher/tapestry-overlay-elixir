
defmodule Tapestry.Application do

  def parse_args(args) do
    if(length(args) != 2) do
      raise(ArgumentError, "expected 2 arguments (number of nodes, number of requests), recieved #{length(args)}")
    else
      {Integer.parse(List.first(args)), Integer.parse(List.last(args))}
    end
  end

  def spawn_peers(num_nodes) do
    if(num_nodes > 0) do
      Tapestry.Peer.start_link("node#{num_nodes}")
      spawn_peers(num_nodes-1)
    end
  end


  def main(_args \\ []) do

    # {_nodes, _requests} = parse_args(args)

    IO.puts("bruh")
    spawn_peers(15)


    {:ok, pid} = Tapestry.Collector.start_link()
    Process.monitor(pid)
    receive do
      {:DOWN, _ref, :process, _object, _reason} ->
        nil
    end
  end
end

Tapestry.Application.main()
