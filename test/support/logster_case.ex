defmodule Logster.Case do
  use ExUnit.CaseTemplate

  setup tags do
    Application.get_all_env(:logster)
    |> Enum.each(fn {k, _} -> Application.delete_env(:logster, k) end)

    if config = tags[:with_config] do
      Application.put_all_env(logster: config)
    end

    :ok
  end
end
