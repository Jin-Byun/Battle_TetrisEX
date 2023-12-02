defmodule BattleTetrisWeb.ChatLive.Room do
  use Phoenix.Component
  alias BattleTetrisWeb.ChatLive.{Messages, Message, GameLive}

  def show(assigns) do
    ~H"""
    <div id={"room-#{@room.id}"} class="flex flex-row">
      <.live_component
        module={GameLive}
        room_id={@room.id}
        sender_id={@current_user_id}
        id={"game-#{@current_user_id}"}
        is_self={true}
      />
      <.live_component
      :if={@present != nil && map_size(@present) > 1}
        module={GameLive}
        room_id={@room.id}
        sender_id={@current_user_id}
        id={"game-other"}
        is_self={false}
      />
      <div class="w-1/4 ml-auto p-2 outline outline-2 outline-blue-500/50 rounded">
        <Messages.list_messages messages={@messages} />
        <.live_component
          module={Message.Form}
          room_id={@room.id}
          sender_id={@current_user_id}
          id={"room-#{@room.id}-message-form"}
        />
      </div>
    </div>
    """
  end
end
