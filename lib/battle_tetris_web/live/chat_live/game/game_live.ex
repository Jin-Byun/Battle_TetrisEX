defmodule BattleTetrisWeb.ChatLive.GameLive do
  use BattleTetrisWeb, :live_component
  import BattleTetrisWeb.GameComponents
  alias BattleTetris.{Game, Board}
  alias BattleTetrisWeb.Endpoint

  @impl true
  def render(assigns) do
    ~H"""
    <div class="game rounded">
      <div class="panel">
        <div class="panel-box">
          <h3 class="panel-box-title">Next</h3>
          <div class="panel-box-content">
            <%= if @is_self || @game_state.state != :new do %>
              <.queue queue={@game_state.block_queue} />
            <% end %>
          </div>
        </div>
        <div class="panel-box">
          <h3 class="panel-box-title">Score</h3>
          <div class="panel-box-content score"><%= @game_state.score %></div>

          <h3 class="panel-box-title">Lines</h3>
          <div class="panel-box-content lines"><%= @game_state.lines %></div>

          <h3 class="panel-box-title">Level</h3>
          <div class="panel-box-content level"><%= @game_state.level %></div>
        </div>
      </div>
      <%= if @is_self do %>
        <div class="board" phx-window-keydown="keydown" phx-window-keyup="keyup" phx-target={@myself}>
          <%= Enum.map((0..(@game_state.board.height - 1)), fn row -> %>
          <div class="board-row">
            <%= Enum.map((0..(@game_state.board.width - 1)), fn column -> %>
            <% block_type = Board.block_type_at(@game_state.board, {column, row}) %>
            <div class={"block-part block-part--#{block_type || "nil"}"} ></div>
            <% end) %>
          </div>
          <% end) %>

          <%= if @game_state.state == :game_over do %>
            <.game_over />
          <% end %>

          <%= if @game_state.state == :new do %>
            <.controls />
          <% end %>
        </div>
      <% else %>
        <div class="board">
          <%= Enum.map((0..(@game_state.board.height - 1)), fn row -> %>
          <div class="board-row">
            <%= Enum.map((0..(@game_state.board.width - 1)), fn column -> %>
            <% block_type = Board.block_type_at(@game_state.board, {column, row}) %>
            <div class={"block-part block-part--#{block_type || "nil"}"} ></div>
            <% end) %>
          </div>
          <% end) %>

          <%= if @game_state.state == :game_over do %>
            <.game_over />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def mount(socket) do
    socket =
      if connected?(socket) do  # 2nd invocation
        {:ok, game} = Game.start_link()
        socket
        |> assign(:game, game)
        |> assign(:game_state, Game.get_state(game))
      else  # 1st invocation
        assign(socket, :game_state, Game.new_dummy_game())
      end
    {:ok, socket}
  end

  def handle_event("start", _value, socket) do
    case socket.assigns.game_state.state do
      :new ->
        :ok = Game.start(socket.assigns.game)
      :game_over ->
        :ok = Game.restart(socket.assigns.game)
      _ ->
        :ok
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event("keydown", %{"key" => "ArrowLeft"}, socket) do
    :ok = Game.move(socket.assigns.game, :left)
    {:noreply, socket}
  end

  @impl true
  def handle_event("keydown", %{"key" => "ArrowRight"}, socket) do
    :ok = Game.move(socket.assigns.game, :right)
    {:noreply, socket}
  end

  @impl true
  def handle_event("keydown", %{"key" => "ArrowDown"}, socket) do
    case socket.assigns.game_state.state do
      :running ->
        :ok = Game.fast_mode_on(socket.assigns.game)
      _ ->
        :ok
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event(
    "keydown",
    %{"key" => " "},
    %{assigns: assigns} = socket) do
    case assigns.game_state.state do
      :new ->
        # :ok = Game.start(assigns.game)
        Endpoint.broadcast("room:#{assigns.room_id}", "start", %{method: "start"})
      :game_over ->
        Endpoint.broadcast("room:#{assigns.room_id}", "restart", %{method: "restart"})
      _ ->
        :ok
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event("keydown", %{"key" => "ArrowUp"}, socket) do
    :ok = Game.rotate(socket.assigns.game)
    {:noreply, socket}
  end

  @impl true
  def handle_event("keydown", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("keyup", %{"key" => "ArrowDown"}, socket) do
    case socket.assigns.game_state.state do
      :running ->
        :ok = Game.fast_mode_off(socket.assigns.game)
      _ ->
        :ok
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("keyup", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def update(%{method: "start"}, socket) do
    Game.start(socket.assigns.game)
    {:ok, socket}
  end
  @impl true
  def update(%{method: "restart"}, socket) do
    Game.restart(socket.assigns.game)
    {:ok, socket}
  end
  @impl true
  def update(%{id: "game-other", game_state: game}, socket) do
    {:ok, assign(socket, game_state: game)}
  end

  @impl true
  def update(%{game_state: game}, %{assigns: assigns} = socket) do
    if assigns.is_self do
      Endpoint.broadcast(
        "room:#{assigns.room_id}",
        "update_other",
        %{game_state: game, sender_id: assigns.sender_id})
      if game.line_to_append > 0 do
        Endpoint.broadcast(
          "room:#{assigns.room_id}",
          "obstruct",
          %{lines: game.line_to_append, sender_id: assigns.sender_id})
      end
    end
    {:ok, assign(socket, game_state: game)}
  end
  @impl true
  def update(data, socket), do: {:ok, assign(socket, data)}
end
