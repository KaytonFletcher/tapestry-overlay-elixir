defmodule Tapestry.Helpers do

  def get_level(id1, id2, level) do
    if(id1 != 0 && id2 != 0 && rem(id1, 10) == rem(id2, 10)) do
      get_level(div(id1, 10), div(id2, 10), level+1)
    else
      level
    end
  end

  def get_level(id1, id2) do
    get_level(id1, id2, 0)
  end




end