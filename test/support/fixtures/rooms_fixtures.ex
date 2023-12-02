defmodule BattleTetris.RoomsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `BattleTetris.Rooms` context.
  """

  @doc """
  Generate a room.
  """
  def room_fixture(attrs \\ %{}) do
    {:ok, room} =
      attrs
      |> Enum.into(%{
        description: "some description",
        name: "some name"
      })
      |> BattleTetris.Rooms.create_room()

    room
  end
end
