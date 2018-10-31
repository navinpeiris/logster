defmodule Logster.JSONFormatter do
  def format(params) do
    params
    |> Enum.into(%{})
    |> Jason.encode!()
  end
end
