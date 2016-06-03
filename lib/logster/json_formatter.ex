defmodule Logster.JSONFormatter do

  def format(params) do
    params
    |> Enum.into(%{})
    |> Poison.encode!
  end
end
