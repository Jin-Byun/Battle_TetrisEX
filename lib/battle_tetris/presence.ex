defmodule BattleTetris.Presence do
  use Phoenix.Presence,
    otp_app: :stream_chat,
    pubsub_server: BattleTetris.PubSub
end
