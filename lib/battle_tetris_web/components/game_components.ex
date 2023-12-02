defmodule BattleTetrisWeb.GameComponents do
  use Phoenix.Component
  alias BattleTetris.Block

  def game_over(assigns) do
    ~H"""
    <div class="overlay">
      <div class="overlay-content">
        <div class="game-over">
          <h2>Game Over</h2>
          <p>Press <kbd class="key down">Space</kbd> to restart.</p>
        </div>
      </div>
    </div>
    """
  end

  def controls(assigns) do
    ~H"""
    <div class="overlay">
      <div class="overlay-content">
        <h2>Controls</h2>
        <div class="controls">
          <div class="label rotate">Rotate</div>
          <div class="label left">Left</div>
          <kbd class="key up">▲</kbd>
          <kbd class="key left">◀</kbd>
          <kbd class="key down">▼</kbd>
          <kbd class="key right">▶</kbd>
          <div class="label right">Right</div>
          <div class="label down"><div>Faster</div><div>(hold)</div></div>
          <kbd class="key space">Space</kbd>
          <div class="label space">Start</div>
          <div class="label space">Start</div>
          <!--
          <div><button class="label space" phx-click="start">Start</button></div>
    -->
        </div>
      </div>
    </div>
    """
  end

  def queue(assigns) do
    ~H"""
    <div class="board">
      <% width = 4 %>
      <% height = 3 %>
      <%= Enum.map(@queue, fn block_type -> %>
      <% block = apply(Block, block_type, []) %>
      <%= 0..(height - 1) |> Enum.map(fn row -> %>
      <div class="board-row">
        <%= 0..(width - 1) |> Enum.map(fn column -> %>
        <%
          klass =
          if block.parts |> Enum.any?(fn part -> part == {column, row} end) do
          "block-part--#{block_type}"
          else
          "block-part--nil"
          end
        %>
          <div class={"block-part #{klass}"} ></div>
        <% end) %>
      </div>
      <% end) %>
    <% end) %>
    </div>
    """
  end
end
