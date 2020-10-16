defmodule Logster.StringFormatter do
  def format(params) do
    params
    |> Enum.map(&format_field/1)
    |> Enum.intersperse(?\s)
  end

  defp format_field({key, value}) do
    [to_string(key), "=", format_value(value)]
  end

  defp format_value(value) when is_binary(value), do: value
  defp format_value(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 3)
  defp format_value(value) when is_atom(value) or is_integer(value), do: to_string(value)

  defp format_value(value) when is_map(value) do
    case Jason.encode(value) do
      {:ok, json} -> json
      {:error, _} -> inspect(value)
    end
  end

  defp format_value(value), do: inspect(value)
end
