defmodule Tapestry.Helpers do
  @id_length 16
  @total_bits 256
  @bits_removed (@total_bits-@id_length)


  defp get_level(id1, id2, level) do
    if(id1 != 0 && id2 != 0 && rem(id1, 10) == rem(id2, 10)) do
      get_level(div(id1, 10), div(id2, 10), level+1)
    else
      level
    end
  end

  def get_level(id1, id2) do
    get_level(id1, id2, 0)
  end

  def generate_id(str) do
    <<id::@id_length, _::@bits_removed, >> = :crypto.hash(:sha256, str)
    id
  end

  def get_neighbors_at_lv(neighbors, lv) do
    Enum.flat_map(neighbors, fn {{level, _rem}, v} ->
      if(level === lv) do
        [v]
      else
        []
      end

    end)
  end
end
