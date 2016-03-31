defmodule Logster.Plugs.ChangeLogLevelTest do
  use ExUnit.Case
  import Plug.Test

  defmodule MyUpdatedLogLevelPlug do
    use Plug.Builder

    plug Logster.Plugs.ChangeLogLevel, to: :error
  end

  defmodule MyDefaultLogLevelPlug do
    use Plug.Builder

    plug :passthrough

    defp passthrough(conn, _) do
      Plug.Conn.send_resp(conn, 200, "Passthrough")
    end
  end

  test "sets the log level in the conn if a level is specified" do
    conn = conn(:get, "/") |> MyUpdatedLogLevelPlug.call([])

    assert conn.private.logster_log_level == :error
  end

  test "does not set the log level in the conn if the plug is not specified" do
    conn = conn(:get, "/") |> MyDefaultLogLevelPlug.call([])

    refute conn.private |> Map.has_key?(:logster_log_level)
  end
end
