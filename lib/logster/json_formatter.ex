defmodule Logster.JSONFormatter do
  def format(params) do
    params
    |> Enum.into(%{})
    |> Jason.encode_to_iodata!()
  end
end
