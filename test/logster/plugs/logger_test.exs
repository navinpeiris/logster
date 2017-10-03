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

  defmodule MyJSONPlug do
    use Plug.Builder

    plug Logster.Plugs.Logger,
      formatter: Logster.JSONFormatter

    plug Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      pass: ["*/*"],
      json_decoder: Poison
    plug :passthrough

    defp passthrough(conn, _) do
      Plug.Conn.send_resp(conn, 200, "Passthrough")
    end
  end

  defmodule MyCustomFieldsPlug do
    use Plug.Builder

    plug Logster.Plugs.Logger,
      custom_fields: Logster.Plugs.LoggerTest.MyCustomFields
    plug Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      pass: ["*/*"],
      json_decoder: Poison
    plug :passthrough

    defp passthrough(conn, _) do
      Plug.Conn.send_resp(conn, 200, "Passthrough")
    end
  end

  defmodule MyCustomFields do
    def custom_fields(conn) do
      []
      |> Keyword.put(:scheme, conn.scheme)
      |> Keyword.put(:host, conn.host)
    end
  end

  defmodule MyCustomLogMetadata do
    use Plug.Builder
    plug Logster.Plugs.Logger
    plug Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      pass: ["*/*"],
      json_decoder: Poison
    plug :passthrough

    defp passthrough(conn, _) do
      Logger.metadata(%{custom_metadata: "OK"})
      Plug.Conn.send_resp(conn, 200, "Passthrough")
    end
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

  test "handles params with spaces" do
    {_conn, message} = conn(:post, "/hello/world", [foo: "one two three"]) |> call
    assert message =~ ~s(params={"foo":"one two three"})
  end

  test "supports non-printable ascii params" do
    {_conn, message} = conn(:get, "/?v=ok%85ok") |> call
    assert message =~ "ok%85ok"
  end

  test "logs file upload params" do
    {_conn, message} = conn(:post, "/hello/world", [upload: %Plug.Upload{content_type: "image/png", filename: "blah.png"}]) |> call

    assert message =~ ~s(params={"upload":{"path":null,"filename":"blah.png","content_type":"image/png"})
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

  test "filters parameters from the log" do
    {_conn, message} = conn(:post, "/hello/world", [password: :bar, foo: [password: :other]]) |> call

    assert message =~ ~s("password":"[FILTERED]")
    assert message =~ ~s("foo":{"password":"[FILTERED]"})
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

  test "logs to json with the JSONFormatter" do
    {_conn, message} = capture_log fn ->
      conn(:get, "/good") |> MyJSONPlug.call([])
    end
    json = message
    |> String.split
    |> Enum.at(3)
    assert %{"path" =>  "/good"} = decoded = Poison.decode!(json)
    %{"duration" => duration} = decoded
    assert is_float(duration)
  end

  test "dump metadata into logs" do
    {_conn, message} = capture_log fn ->
      conn(:get, "/good") |> MyCustomLogMetadata.call([])
    end
    assert message =~ "custom_metadata=OK"
  end

  test "Custom fields" do
    {_conn, message} = capture_log fn ->
      conn(:get, "/foo") |> MyCustomFieldsPlug.call([])
    end

    assert message =~ "host=www.example.com"
    assert message =~ "scheme=http"
  end

  test "[TextFormatter] log headers: no default headers, no output" do
    Application.put_env(:logster, :allowed_headers, [])
    {_conn, message} = conn(:post, "/hello/world", []) |> put_req_header("x-test-header", "test value") |> call

    refute message =~ ~s(headers)
  end

  test "[JSONFormatter] log headers: no default headers, no output" do
    Application.put_env(:logster, :allowed_headers, [])
    {_conn, message} = capture_log fn ->
      conn(:post, "/hello/world", []) |> put_req_header("x-test-header", "test value") |> MyJSONPlug.call([])
    end
    json = message
    |> String.split
    |> Enum.at(3)
    refute Poison.decode!(json)[:headers]
  end

  test "[TextFormatter] log headers: test values" do
    Application.put_env(:logster, :allowed_headers, ["my-header-one", "my-header-two"])
    {_conn, message} = conn(:post, "/hello/world", []) |> put_req_header("my-header-one", "test-value-1") |> call

    assert message =~ ~s("test-value-1")
  end

  test "[JSONFormatter] log headers: test values" do
    Application.put_env(:logster, :allowed_headers, ["my-header-one", "my-header-two"])
    {_conn, message} = capture_log fn ->
      conn(:post, "/hello/world", [])
      |> put_req_header("my-header-one", "test-value-1")
      |> put_req_header("my-header-three", "test-value-3")
      |> MyJSONPlug.call([])
    end
    json = message
    |> String.split
    |> Enum.at(3)
    assert Poison.decode!(json)["headers"]["my-header-one"] == "test-value-1"
    refute Poison.decode!(json)["headers"]["my-header-two"]
    refute Poison.decode!(json)["headers"]["my-header-three"]
  end
end
