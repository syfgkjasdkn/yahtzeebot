defmodule UBot do
  @moduledoc false

  alias TDLib.{Method, Object}
  use GenServer

  @session :ubot2
  @seeditbot_id 615_942_994

  require Logger
  require Record
  Record.defrecord(:state, [:pid, :phone_number, :bot_id, authed?: false])

  @doc false
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def auth(code) do
    GenServer.call(__MODULE__, {:auth, code})
  end

  @doc false
  def init(opts) do
    api_id = opts[:api_id] || raise("need :api_id")
    api_hash = opts[:api_hash] || raise("need :api_hash")
    phone_number = opts[:phone_number] || raise("need :phone_number")
    bot_id = opts[:bot_id] || raise("need :bot_id set")

    tdlib_database_directory =
      opts[:tdlib_database_directory] || raise("need :tdlib_database_directory")

    config =
      struct(
        TDLib.default_config(),
        %{api_id: api_id, api_hash: api_hash, database_directory: tdlib_database_directory}
      )

    {:ok, pid} = TDLib.open(@session, self(), config)

    # Set TDLib (C++) verbosity to 0
    TDLib.transmit(@session, "verbose 0")

    {:ok,
     state(
       pid: pid,
       phone_number: phone_number,
       bot_id: bot_id
     )}
  end

  @doc false
  def handle_call(msg, from, state)

  def handle_call({:auth, code}, _from, state(authed?: false) = state) do
    reply = TDLib.transmit(@session, %Method.CheckAuthenticationCode{code: code})
    {:reply, reply, state(state, authed?: true)}
  end

  def handle_call({:auth, _code}, _from, state) do
    Logger.warn("ignoring auth code")
    {:reply, :ok, state}
  end

  @doc false
  def handle_info(msg, state)

  # TODO refactor into multiple clauses
  def handle_info(
        {:recv, message},
        state(phone_number: phone_number, bot_id: our_bot_id) = state
      ) do
    state =
      case message do
        %Object.UpdateAuthorizationState{authorization_state: auth_state} ->
          case auth_state do
            %Object.AuthorizationStateWaitPhoneNumber{} ->
              TDLib.transmit(@session, %Method.SetAuthenticationPhoneNumber{
                phone_number: phone_number,
                allow_flash_call: false
              })

              state

            %Object.AuthorizationStateWaitCode{} ->
              state(state, authed?: false)

            %Object.AuthorizationStateReady{} ->
              state(state, authed?: true)

            _other ->
              state
          end

        %Object.UpdateNewMessage{message: message} ->
          _handle_message(message, our_bot_id)
          state

        _message ->
          state
      end

    {:noreply, state}
  end

  defp _handle_message(
         %Object.Message{
           chat_id: chat_id,
           is_outgoing: is_outgoing
         } = message,
         our_bot_id
       ) do
    if chat_id in tracked_chat_ids() do
      unless is_outgoing do
        _do_handle_message(message, our_bot_id)
      end
    end
  end

  defp _handle_message(_message, _our_bot_id) do
    :ignore
  end

  # TODO refactor, don't rely on message structure
  defp _do_handle_message(
         %Object.Message{
           chat_id: chat_id,
           content: %Object.MessageText{
             text: %Object.FormattedText{
               entities: entities,
               text: text
             }
           },
           sender_user_id: @seeditbot_id
         },
         our_bot_id
       ) do
    if _tip?(text) do
      if txid = _extract_txid(entities) do
        case _extract_tip_participants(entities) do
          [tipper_id, ^our_bot_id] ->
            username = _extract_tipper_name(entities, text)

            # TODO
            spawn(fn ->
              _process_tip(tipper_id, username, chat_id, txid)
            end)

          _other ->
            nil
        end
      else
        Logger.error(~s[couldn't extract txid from "#{text}"])
      end
    end
  end

  defp _do_handle_message(_message, _our_bot_id) do
    :ignore
  end

  @doc false
  def _process_tip(tipper_id, tipper_username, chat_id, txid) do
    case Core.process_tip(tipper_id, txid) do
      {:ok, :credited, pool_size} ->
        TGBot.adapter().send_message(chat_id, """
        @#{tipper_username} you tipped an invalid amount.

        Pool size: #{pool_size} TRX
        """)

      {:ok, rolls_count, pool_size} ->
        TGBot.adapter().send_message(chat_id, """
        @#{tipper_username} now has #{rolls_count} roll(s)

        Pool size: #{pool_size} TRX
        """)

      {:error, :invalid_contract} ->
        {rolls, trx} = Core.rolls_to_trx_ratio()

        TGBot.adapter().send_message(chat_id, """
        🚨 The bot only accepts #{trx} TRX tips.

        Try /tip #{trx} to get #{rolls} rolls
        """)

      {:error, :no_transfer} ->
        TGBot.adapter().send_message(chat_id, """
        🚨 Failed to fetch the transfer
        """)
    end
  end

  defp tracked_chat_ids do
    Application.get_env(:ubot, :tracked_chat_ids) || raise("need ubot.tracked_chat_ids")
  end

  defp _tip?(text) do
    String.contains?(text, "tipped")
  end

  defp _extract_tipper_name(
         [
           %{
             "@type" => "textEntity",
             "length" => len,
             "offset" => 0,
             "type" => %{"@type" => "textEntityTypeMentionName"}
           }
           | _rest
         ],
         text
       ) do
    <<username::size(len)-bytes, _rest::bytes>> = text
    username
  end

  defp _extract_tip_participants(entities) do
    entities
    |> Enum.map(fn
      %{
        "type" => %{
          "@type" => "textEntityTypeMentionName",
          "user_id" => user_id
        }
      } ->
        user_id

      _ ->
        nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp _extract_txid(entities) do
    Enum.find_value(entities, fn
      %{
        "type" => %{
          "@type" => "textEntityTypeTextUrl",
          "url" => "https://tronscan.org/" <> path
        }
      } ->
        path
        |> :binary.split("/", [:global])
        |> List.last()

      _ ->
        false
    end)
  end
end
