
defmodule Tapestry.Application do

  def parse_args(args) do
    if(length(args) != 2) do
      raise(ArgumentError, "expected 2 arguments (number of nodes, number of requests), recieved #{length(args)}")
    else
      {nodes, _ok} = Integer.parse(List.first(args))
      {reqs, _ok} =Integer.parse(List.last(args))
      {nodes, reqs}
    end
  end


  def main(args \\ []) do

    {nodes, requests} = parse_args(args)

    {:ok, pid} = Tapestry.Manager.start_link({nodes, requests})


    Process.monitor(pid)
    receive do
      {:DOWN, _ref, :process, _object, _reason} ->
        nil
    end
  end
end

