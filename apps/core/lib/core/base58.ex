defmodule Core.Base58 do
  @moduledoc false
  @alphabet '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'

  def encode(data, hash \\ "")

  def encode(data, hash) when is_binary(data) do
    encode_zeros(data) <> encode(:binary.decode_unsigned(data), hash)
  end

  def encode(0, hash), do: hash

  def encode(data, hash) do
    character = <<Enum.at(@alphabet, rem(data, 58))>>
    encode(div(data, 58), character <> hash)
  end

  defp encode_zeros(data) do
    String.duplicate(<<Enum.at(@alphabet, 0)>>, leading_zeros(data))
  end

  def decode(enc) do
    enc
    |> to_charlist
    |> _decode(0)
    |> :binary.encode_unsigned()
  end

  defp _decode([], acc), do: acc

  defp _decode([c | cs], acc) do
    _decode(cs, acc * 58 + Enum.find_index(@alphabet, &(&1 == c)))
  end

  defp leading_zeros(data) do
    data
    |> :binary.bin_to_list()
    |> Enum.find_index(&(&1 != 0))
  end

  def encode_check(data) do
    encode(data <> checksum(data))
  end

  defp checksum(data) do
    <<verification_code::4-bytes, _rest::bytes>> = sha256(sha256(data))
    verification_code
  end

  defp sha256(data) do
    :crypto.hash(:sha256, data)
  end
end
