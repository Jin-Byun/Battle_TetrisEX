defmodule BattleTetris.Game do
  use GenServer

  require Logger

  alias BattleTetris.{Board, BlockQueue, Score, Row}
  alias BattleTetrisWeb.Endpoint

  defstruct board: nil,
            subscriber: nil,
            state: :new,
            block_queue: nil,
            lines: 0,
            lines_use: 0,
            line_to_append: 0,
            score: 0,
            level: 1,
            tick_throttle_counter: 0,
            tick_frequency: 1

  @type state :: :new | :running | :game_over | :ready
  @type t() :: %__MODULE__{
          board: Board.t(),
          subscriber: pid(),
          state: state(),
          block_queue: BlockQueue.t(),
          lines: integer(),
          lines_use: integer(),
          line_to_append: integer(),
          score: integer(),
          level: integer(),
          tick_throttle_counter: integer(),
          tick_frequency: integer()
        }

  @tick 50

  # API ######################################################

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @spec obstruct(pid(), integer()) :: :ok
  def obstruct(pid, lines) do
    GenServer.call(pid, {:lines, lines})
  end

  @spec ready(pid()) :: :ok
  def ready(pid) do
    GenServer.call(pid, :ready)
  end

  @spec start(pid()) :: :ok
  def start(pid) do
    GenServer.call(pid, :start)
  end

  @spec restart(pid()) :: :ok
  def restart(pid) do
    GenServer.call(pid, :restart)
  end

  @spec get_state(pid()) :: __MODULE__.t()
  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end

  @spec move(pid(), Board.direction()) :: :ok
  def move(pid, direction) do
    GenServer.call(pid, {:move, direction})
  end

  @spec rotate(pid()) :: :ok
  def rotate(pid) do
    GenServer.call(pid, :rotate)
  end

  @spec fast_mode_on(pid()) :: :ok
  def fast_mode_on(pid) do
    GenServer.call(pid, :fast_mode_on)
  end

  @spec fast_mode_off(pid()) :: :ok
  def fast_mode_off(pid) do
    GenServer.call(pid, :fast_mode_off)
  end

  # This is only exposed so that the LiveView can render a new game during the initial HTTP-only connection
  # without starting the game process.
  def new_dummy_game do
    %{new_game() | block_queue: []}
  end

  # Callbacks ######################################################

  @impl true
  def init(:ok) do
    {:ok, new_game()}
  end

  @impl true
  def handle_call(:start, {from_pid, _from_ref}, game) do
    if game.state == :new do
      game = start_game(game, from_pid)
      send(self(), :inform_subscriber)
      :timer.send_after(@tick, self(), :tick)

      {:reply, :ok, game}
    else
      {:reply, :ok, game}
    end
  end
  def handle_call({:lines, lines}, _from, game) do
    if game.state == :running do
      IO.puts("herre")
      new_board = Board.move_statics(game.board, :up)
      IO.inspect(new_board)
      send(self(), :inform_subscriber)
      {:reply, :ok, %{game | board: new_board}}
    else
      {:reply, :ok, game}
    end

  end

  @impl true
  def handle_call(:restart, _from, game) do
    if game.state == :game_over do
      new_game = start_game(new_game(), game.subscriber)
      send(self(), :inform_subscriber)
      :timer.send_after(@tick, self(), :tick)

      {:reply, :ok, new_game}
    else
      {:reply, :ok, game}
    end
  end

  @impl true
  def handle_call(:get_state, _from, game) do
    {:reply, game, game}
  end

  @impl true
  def handle_call({:move, direction}, _from, game) do
    if game.state == :running do
      new_board = Board.move(game.board, direction)

      send(self(), :inform_subscriber)
      {:reply, :ok, %{game | board: new_board}}
    else
      {:reply, :ok, game}
    end
  end

  @impl true
  def handle_call(:rotate, _from, game) do
    if game.state == :running do
      new_board = Board.rotate(game.board)

      send(self(), :inform_subscriber)
      {:reply, :ok, %{game | board: new_board}}
    else
      {:reply, :ok, game}
    end
  end

  @impl true
  def handle_call(:fast_mode_on, _from, game) do
    game = %{game | tick_frequency: fast_tick_frequency()}
    {:reply, :ok, game}
  end

  def handle_call(:fast_mode_off, _from, game) do
    game = %{game | tick_frequency: normal_tick_frequency(game)}
    {:reply, :ok, game}
  end

  @impl true
  def handle_info(:tick, game) do
    game =
      if game.tick_throttle_counter == 0 do
        do_advance(game)
      else
        game
      end

    if game.state == :running do
      :timer.send_after(@tick, self(), :tick)
    end

    {:noreply,
     %{game | tick_throttle_counter: rem(game.tick_throttle_counter + 1, game.tick_frequency)}}
  end

  @impl true
  def handle_info(:inform_subscriber, game) do
    if game.subscriber do
      send(game.subscriber, game)
    end

    {:noreply, game}
  end

  @impl true
  def handle_info("obstruct", lines) do
    {_,_,game} = self().get_state()
    IO.puts("here is 206")
    static_blocks = Board.shift_up(game.board.static_blocks)
    {:noreply, %{game | board: %{game.board | static_blocks: []}}}
  end


  defp do_advance(game) do
    if game.state == :running do
      game =
        if game.board.falling_block do
          {new_board, lines_cleared} = Board.advance(game.board)
          lines = game.lines + lines_cleared
          tmp_lines = game.lines_use + lines_cleared
          line_to_append = lines_cleared
          lines_use = rem(tmp_lines, 2)

          score = game.score + Score.lines_cleared(game.level, lines_cleared)
          level = Score.level(lines)
          %{game | board: new_board, lines_use: lines_use, line_to_append: line_to_append, lines: lines, score: score, level: level}
        else
          {block_type, queue} = BlockQueue.pop(game.block_queue)

          case Board.set_falling_block(game.board, block_type) do
            {:ok, board} ->
              %{game | board: board, block_queue: queue}

            {:game_over, board} ->
              %{game | state: :game_over, board: board, block_queue: queue}
          end
        end

      send(self(), :inform_subscriber)

      game
    else
      game
    end
  end

  defp new_game() do
    queue = BlockQueue.new()
    board = %Board{}

    %__MODULE__{board: board, block_queue: queue, tick_frequency: normal_tick_frequency()}
  end

  defp start_game(game, subscriber) do
    {block_type, queue} = BlockQueue.pop(game.block_queue)
    {:ok, board} = Board.set_falling_block(game.board, block_type)
    %{game | state: :running, subscriber: subscriber, board: board, block_queue: queue}
  end

  defp normal_tick_frequency(game \\ %{level: 1}) do
    Enum.max([3, Score.max_level() - game.level + 3])
  end

  defp fast_tick_frequency() do
    1
  end
end
