defmodule Logster.Formatters.String do
  def format(params) when is_list(params) do
    params
    |> Enum.map(&format_field/1)
    |> Enum.intersperse(?\s)
  end

  def format(params) when is_binary(params), do: params
  def format(params), do: inspect(params)

  defp format_field({key, value}), do: [to_string(key), "=", format_value(value)]

  defp format_field(value), do: value

  defp format_value(value) when is_binary(value), do: value
  defp format_value(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 3)
  defp format_value(value) when is_atom(value) or is_integer(value), do: to_string(value)

  defp format_value(value) when is_map(value) do
    case Jason.encode_to_iodata(value) do
      {:ok, json_iodata} -> json_iodata
      {:error, _} -> inspect(value)
    end
  end

  defp format_value(value), do: inspect(value)
end
