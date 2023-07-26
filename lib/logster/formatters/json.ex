defmodule Logster.Formatters.JSON do
  def format(data) when is_map(data) do
    case data |> Jason.encode_to_iodata() do
      {:ok, json} -> json
      {:error, _} -> %{msg: inspect(data)} |> format()
    end
  end

  def format([]), do: ""
  def format([{_, _} | _] = data), do: data |> Enum.into(%{}) |> format()

  def format(data) when is_binary(data) or is_list(data), do: %{msg: data} |> format()

  def format(data), do: %{msg: inspect(data)} |> format()
end
