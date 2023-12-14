defmodule BattleTetrisWeb.ChatLive.Root do
  use BattleTetrisWeb, :live_view
  alias BattleTetris.{Chat, Presence}
  alias BattleTetrisWeb.Endpoint
  alias BattleTetrisWeb.ChatLive.{Rooms, Room, GameLive}

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_rooms()
     |> assign_current_users()
     |> assign_active_room()
     |> assign_last_user_message()}
  end

  def handle_params(%{"id" => id}, _uri, %{assigns: %{live_action: :show}} = socket) do
    uid = socket.assigns.current_user.id
    init_list = if connected?(socket) do
      Presence.track(self(), "room:#{id}", socket.id, %{})
      Endpoint.subscribe("room:#{id}")
      Presence.list("room:#{id}")
    end
    messages = Chat.last_ten_messages_for(id)
    {:noreply,
     socket
     |> assign_active_room(id)
     |> assign_current_users(uid)
     |> assign_presence(init_list)
     |> assign_active_room_messages(messages)
     |> assign_oldest_message_id(List.first(messages))}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  def handle_event("load_more", _params, %{assigns: %{oldest_message_id: id}} = socket) do
    messages = Chat.get_previous_n_messages(id, 5)
    {:noreply,
      socket
      |> stream_batch_insert(:messages, messages, at: 0)
      |> assign_oldest_message_id(List.last(messages))}
  end

  def handle_event("delete_message", %{"item_id" => msg_id}, socket) do
    {:noreply, delete_message(socket, msg_id)}
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  def handle_info(%{event: "new_message", payload: %{message: message}}, socket) do
    {:noreply, insert_new_message(socket, message)}
  end

  def handle_info(%{event: "updated_message", payload: %{message: message}}, socket) do
    {:noreply, insert_updated_message(socket, message)}
  end

  # def handle_info(%{event: "start", payload: %{game: game}}, socket) do
  #   {:noreply, insert_updated_message(socket, message)}
  # end

  def handle_info(
      %{event: "presence_diff", payload: %{joins: joins, leaves: leaves}},
      %{assigns: %{present: present}} = socket
    ) do
    new_present =
      present
      |> Map.merge(joins)
      |> Map.filter(fn {key, _val} -> !Map.has_key?(leaves, key) end)
    {:noreply, assign(socket, :present, new_present)}
  end

  def handle_info(
      %{event: "start", payload: %{method: method}},
      %{assigns: %{current_user: current_user}} = socket
    ) do
    uid = current_user.id
    send_update(GameLive, id: "game-#{uid}", method: method)
    {:noreply, socket}
  end
  def handle_info(
      %{event: "restart", payload: %{method: method}},
      %{assigns: %{current_user: current_user}} = socket
    ) do
    uid = current_user.id
    send_update(GameLive, id: "game-#{uid}", method: method)
    {:noreply, socket}
  end

  def handle_info(
      %{event: "update_other", payload: payload},
      %{assigns: %{current_user: current_user}} = socket
    ) do
    sender_id = payload.sender_id
    uid = current_user.id
    if sender_id != uid do
      send_update(GameLive, id: "game-other", game_state: payload.game_state)
    end
    {:noreply, socket}
  end

  def handle_info(
      %{event: "obstruct", payload: payload},
      %{assigns: %{current_user: current_user}} = socket
    ) do
    sender_id = payload.sender_id
    uid = current_user.id
    if sender_id != uid do
      send_update(GameLive, id: "game-#{uid}", lines: payload.lines)
    end
    {:noreply, socket}
  end

  def handle_info(game_state, %{assigns: %{current_user: current_user}} = socket) do
    uid = current_user.id
    send_update(GameLive, id: "game-#{uid}", game_state: game_state)
    {:noreply, socket}
  end

  def delete_message(socket, message_id) do
    msg = Chat.get_message!(message_id)
    Chat.delete_message(msg)
    stream_delete(socket, :messages, msg)
  end

  def insert_new_message(socket, message) do
    socket
    |> stream_insert(:messages, Chat.preload_message_sender(message))
  end

  def insert_updated_message(socket, message) do
    socket
    |> stream_insert(:messages, Chat.preload_message_sender(message), at: -1)
  end

  def assign_rooms(socket), do: assign(socket, :rooms, Chat.list_rooms())

  def assign_active_room(socket, id), do: assign(socket, :room, Chat.get_room!(id))
  def assign_active_room(socket), do: assign(socket, :room, nil)

  def assign_current_users(socket), do: assign(socket, :uid, nil)
  def assign_current_users(socket, id), do: assign(socket, :uid, id)

  def assign_presence(socket, presence), do: assign(socket, :present, presence)

  def assign_active_room_messages(socket, messages), do: stream(socket, :messages, messages)

  def assign_oldest_message_id(socket, nil), do: assign(socket, :oldest_message_id, -1)
  def assign_oldest_message_id(socket, message), do: assign(socket, :oldest_message_id, message.id)

  def assign_last_user_message(%{assigns: %{current_user: current_user}} = socket, message)
      when current_user.id == message.sender_id do
    assign(socket, :message, message)
  end
  def assign_last_user_message(socket, _message), do: socket
  def assign_last_user_message(%{assigns: %{room: nil}} = socket) do
    assign(socket, :message, %Chat.Message{})
  end
  def assign_last_user_message(%{assigns: %{room: room, current_user: current_user}} = socket) do
    assign(socket, :message, get_last_user_message_for_room(room.id, current_user.id))
  end

  def get_last_user_message_for_room(room_id, current_user_id) do
    Chat.last_user_message_for_room(room_id, current_user_id) || %Chat.Message{}
  end
end
