defmodule TGBot do
  @moduledoc false
  require Logger

  @adapter Application.get_env(:tgbot, :adapter) || raise("need tgbot adapter set")

  @spec handle(map) :: any
  def handle(request)

  def handle(%{"message" => %{"chat" => %{"type" => type}, "text" => text} = message})
      when type in ["group", "supergroup", "channel"] do
    handle_public_text(text, message)
  end

  def handle(%{"message" => %{"chat" => %{"type" => "private"}}}) do
    :ignore
  end

  def handle(other) do
    Logger.error("unhandled request:\n\n#{inspect(other)}")
    :ignore
  end

  defp handle_public_text("/rolls_left" <> _maybe_bot_name, %{
         "chat" => %{"id" => chat_id},
         "from" => %{"id" => from_id, "username" => username}
       }) do
    rolls_left = Core.Session.rolls_left(from_id)

    @adapter.send_message(chat_id, """
    @#{username} you have #{rolls_left} roll(s) left
    """)
  end

  defp handle_public_text("/init" <> _maybe_bot_name, %{
         "chat" => %{"id" => chat_id},
         "from" => %{"id" => from_id}
       }) do
    if Core.admin?(from_id) do
      # TODO move this config to :core
      :ok = Application.put_env(:ubot, :tracked_chat_ids, [chat_id])

      @adapter.send_message(chat_id, """
      Initialized the bot for chat id #{chat_id}.
      """)
    end
  end

  defp handle_public_text("/credit" <> _maybe_bot_name, %{
         "chat" => %{"id" => chat_id},
         "from" => %{"id" => from_id, "username" => username}
       }) do
    credit = Core.Session.credit(from_id)

    @adapter.send_message(chat_id, """
    @#{username} your credit is #{credit} TRX
    """)
  end

  defp handle_public_text("/roll" <> _maybe_bot_name, %{
         "chat" => %{"id" => chat_id},
         "from" => %{"id" => from_id, "username" => username}
       }) do
    # TODO maybe use iolists for messages
    case Core.roll(from_id) do
      {:ok, {:win, reward, dice}, txid} ->
        @adapter.send_message(
          chat_id,
          """
          @#{username} rolled #{render_dice(dice)} and won #{render_reward(reward)}

          Tx: <a href="https://tronscan.org/#/transaction/#{txid}">#{txid}</a>
          """,
          parse_mode: "HTML"
        )

      {:ok, {:win, reward, dice}} ->
        @adapter.send_message(chat_id, """
        @#{username} rolled #{render_dice(dice)} and won #{render_reward(reward)}
        """)

      {:ok, {:lose, dice}} ->
        @adapter.send_message(chat_id, """
        @#{username} rolled #{render_dice(dice)} and lost
        """)

      {:error, :no_rolls} ->
        {rolls, trx} = Core.rolls_to_trx_ratio()

        @adapter.send_message(chat_id, """
        @#{username} you don't have any rolls left.

        Please /tip #{trx} the bot to get #{rolls} rolls.
        """)

      {:error, :give_up} ->
        @adapter.send_message(chat_id, """
        🚨 The bot failed to send the reward.
        """)

      {:error, message} ->
        @adapter.send_message(chat_id, """
        🚨 The bot failed to send the reward (#{message}).
        """)
    end
  end

  defp handle_public_text("/pool" <> _maybe_bot_name, %{"chat" => %{"id" => chat_id}}) do
    @adapter.send_message(chat_id, """
    Current pool size is #{Core.pool_size()} TRX
    """)
  end

  defp handle_public_text(_other, _message) do
    :ignore
  end

  @spec token :: String.t()
  def token do
    Application.get_env(:nadia, :token) || raise("need nadia.token")
  end

  defp number_to_emoji(1), do: "1️⃣"
  defp number_to_emoji(2), do: "2️⃣"
  defp number_to_emoji(3), do: "3️⃣"
  defp number_to_emoji(4), do: "4️⃣"
  defp number_to_emoji(5), do: "5️⃣"
  defp number_to_emoji(6), do: "6️⃣"

  defp render_dice(dice) do
    dice
    |> Enum.map(&number_to_emoji/1)
    |> Enum.join("")
  end

  defp render_reward(:extra_roll), do: "extra roll"
  defp render_reward(:large_straight), do: "#{Core.reward_for_large_straight()} TRX"
  defp render_reward(:four_of_kind), do: "#{Core.reward_for_four_of_kind()} TRX"
  defp render_reward(:pool), do: "the pool"

  @doc false
  def adapter do
    @adapter
  end

  def bot_id do
    @adapter.bot_id()
  end

  def set_webhook(url) do
    url
    |> Path.join(token())
    |> @adapter.set_webhook()
  end
end
