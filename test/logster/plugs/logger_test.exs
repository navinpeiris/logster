defmodule Logster.Plugs.LoggerTest do
  use ExUnit.Case
  use Plug.Test

  import ExUnit.CaptureIO
  require Logger

  defmodule MyPlug do
    use Plug.Builder

    plug Logster.Plugs.Logger
    plug Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      pass: ["*/*"],
      json_decoder: Poison
    plug :passthrough

    defp passthrough(conn, _) do
      Plug.Conn.send_resp(conn, 200, "Passthrough")
    end
  end

  defp call(conn) do
    capture_log fn -> MyPlug.call(conn, []) end
  end

  defp put_phoenix_privates(conn) do
    conn
      |> put_private(:phoenix_controller, Logster.Plugs.LoggerTest)
      |> put_private(:phoenix_action, :show)
      |> put_private(:phoenix_format, "json")
  end

  defmodule MyChunkedPlug do
    use Plug.Builder

    plug Logster.Plugs.Logger
    plug Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      pass: ["*/*"],
      json_decoder: Poison
    plug :passthrough

    defp passthrough(conn, _) do
      Plug.Conn.send_chunked(conn, 200)
    end
  end

  defmodule MyHaltingPlug do
    use Plug.Builder, log_on_halt: :debug

    plug :halter
    defp halter(conn, _), do: halt(conn)
  end

  defp capture_log(fun) do
    data = capture_io(:user, fn ->
      Process.put(:capture_log, fun.())
      Logger.flush()
    end)

    {Process.get(:capture_log), data}
  end

  test "logs proper message to console" do
    {_conn, message} = conn(:get, "/") |> call

    assert message =~ "method=GET"
    assert message =~ "path=/"
    assert message =~ "params={}"
    assert message =~ "status=200"
    assert message =~ ~r/duration=\d+.\d{3}/u
    assert message =~ "state=set"

    {_conn, message} = conn(:post, "/hello/world", [foo: :bar]) |> call

    assert message =~ "method=POST"
    assert message =~ "path=/hello/world"
    assert message =~ ~s(params={"foo":"bar"})
    assert message =~ "status=200"
    assert message =~ ~r/duration=\d+.\d{3}/u
    assert message =~ "state=set"
  end

  test "logs phoenix related attributes if present" do
    {_conn, message} = conn(:get, "/") |> call

    assert message =~ "method=GET"
    assert message =~ "path=/"
    assert message =~ "params={}"
    assert message =~ "status=200"
    assert message =~ ~r/duration=\d+.\d{3}/u
    assert message =~ "state=set"
  end

  test "logs paths with double slashes and trailing slash" do
    {_conn, message} = conn(:get, "/hello/world") |> put_phoenix_privates |> call

    assert message =~ "format=json"
    assert message =~ "controller=Logster.Plugs.LoggerTest"
    assert message =~ "action=show"
  end

  test "logs chunked if chunked reply" do
    {_, message} = capture_log(fn ->
       conn(:get, "/hello/world") |> MyChunkedPlug.call([])
    end)

    assert message =~ "state=chunked"
  end

  test "logs halted connections if :log_on_halt is true" do
    {_conn, message} = capture_log fn ->
      conn(:get, "/foo") |> MyHaltingPlug.call([])
    end

    assert message =~ "Logster.Plugs.LoggerTest.MyHaltingPlug halted in :halter/2"
  end
end
