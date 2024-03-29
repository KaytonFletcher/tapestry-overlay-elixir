defmodule Tapestry.Math do
  @id_length 40
  @total_bits 256
  @bits_removed @total_bits - @id_length
  @base 16

  defp get_level(id1, id2, level) do
    if(id1 != 0 && id2 != 0 && rem(id1, @base) == rem(id2, @base)) do
      get_level(div(id1, @base), div(id2, @base), level + 1)
    else
      level
    end
  end

  def get_level(id1, id2) do
    get_level(id1, id2, 0)
  end

  def generate_id(str) do
    <<id::@id_length, _::@bits_removed>> = :crypto.hash(:sha256, str)
    id
  end

  def get_neighbors_at_lv(neighbors, lv) do
    Enum.flat_map(neighbors, fn {{level, _rem}, {pid, id}} ->
      if(level === lv) do
        [{pid, id}]
      else
        []
      end
    end)
  end

  def get_bp_at_lv(bp, lv) do
    Enum.flat_map(bp, fn {{level, _rem}, v} ->
      if(level === lv) do
        [v]
      else
        []
      end
    end)
  end

  def rem_at_level(lv, id) do
    rem(div(id, trunc(:math.pow(@base, lv))), @base)
  end

  def is_closer?(to, id1, id2) do
    if abs(id1 - to) > abs(id2 - to) do
      true
    else
      false
    end
  end

  defp find_peer_at_level(current_id, _lv, _r, _neighbors, @base) do
    {self(), current_id}
  end

  defp find_peer_at_level(current_id, lv, r, neighbors, count) do
    case Map.get(neighbors, {lv, r}) do
      nil -> find_peer_at_level(current_id, lv, rem(r + 1, @base), neighbors, count + 1)
      {pid, id} -> {pid, id}
    end
  end

  def find_peer_at_level(current_id, lv, r, neighbors) do
    find_peer_at_level(current_id, lv, r, neighbors, 0)
  end
end
