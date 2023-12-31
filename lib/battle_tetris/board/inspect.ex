defimpl Inspect, for: BattleTetris.Board do
  @doc """
    Makes a very simple ASCII image of the board.
  """
  def inspect(%BattleTetris.Board{} = board, _opts) do
    0..(board.height - 1)
    |> Enum.map(fn row ->
      0..(board.width - 1)
      |> Enum.map(fn column ->
        block_symbol(BattleTetris.Board.block_type_at(board, {column, row}))
      end)
      |> Enum.join(" ")
    end)
    |> Enum.join("\n")
    |> Kernel.<>("\n")
  end

  defp block_symbol(:o), do: "o"
  defp block_symbol(:i), do: "i"
  defp block_symbol(:t), do: "t"
  defp block_symbol(:j), do: "j"
  defp block_symbol(:l), do: "l"
  defp block_symbol(:z), do: "z"
  defp block_symbol(:s), do: "s"
  defp block_symbol(nil), do: "."
end
