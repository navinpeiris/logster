defmodule Logster.Plugs.LoggerTest do
  use ExUnit.Case
  use Plug.Test

  import ExUnit.CaptureLog
  require Logger

  defmodule MyPlug do
    use Plug.Builder

    plug Logster.Plugs.Logger

    plug Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      pass: ["*/*"],
      json_decoder: Jason

    plug :passthrough

    defp passthrough(conn, _) do
      Plug.Conn.send_resp(conn, 200, "Passthrough")
    end
  end

  defmodule MyUnfetchedParamsPlug do
    use Plug.Builder

    plug Logster.Plugs.Logger
    plug :passthrough

    defp passthrough(conn, _) do
      Plug.Conn.send_resp(conn, 200, "Passthrough")
    end
  end

  defmodule MyStruct do
    defstruct name: "John", age: 27
  end

  defmodule MyStructParamsPlug do
    use Plug.Builder

    plug Logster.Plugs.Logger
    plug :passthrough

    defp passthrough(conn, _) do
      conn = %{conn | params: %MyStruct{}}
      Plug.Conn.send_resp(conn, 200, "Passthrough")
    end
  end

  defmodule MyMapNotJsonablePlug do
    use Plug.Builder

    plug Logster.Plugs.Logger
    plug :passthrough

    defp passthrough(conn, _) do
      conn = %{conn | params: %{my_tuple: {27}}}
      Plug.Conn.send_resp(conn, 200, "Passthrough")
    end
  end

  defmodule MyChunkedPlug do
    use Plug.Builder

    plug Logster.Plugs.Logger

    plug Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      pass: ["*/*"],
      json_decoder: Jason

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
      json_decoder: Jason

    plug :passthrough

    defp passthrough(conn, _) do
      Plug.Conn.send_resp(conn, 200, "Passthrough")
    end
  end

  defmodule MyRenameFieldsPlug do
    use Plug.Builder

    plug Logster.Plugs.Logger,
      renames: %{duration: :responsetime, status: :mystatus}

    plug Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      pass: ["*/*"],
      json_decoder: Jason

    plug :passthrough

    defp passthrough(conn, _) do
      Plug.Conn.send_resp(conn, 200, "Passthrough")
    end
  end

  defmodule MyExcludeFieldsPlug do
    use Plug.Builder

    plug Logster.Plugs.Logger,
      excludes: [:params]

    plug :passthrough

    defp passthrough(conn, _) do
      Plug.Conn.send_resp(conn, 200, "Passthrough")
    end
  end

  defp put_phoenix_privates(conn) do
    conn
    |> put_private(:phoenix_controller, Logster.Plugs.LoggerTest)
    |> put_private(:phoenix_action, :show)
    |> put_private(:phoenix_format, "json")
  end

  defp call_and_capture_log(conn, plug), do: capture_log(fn -> plug.call(conn, []) end)

  test "logs proper message to console" do
    message = conn(:get, "/") |> call_and_capture_log(MyPlug)

    assert message =~ "method=GET"
    assert message =~ "path=/"
    assert message =~ "params={}"
    assert message =~ "status=200"
    assert message =~ ~r/duration=\d+.\d{3}/u
    assert message =~ "state=set"

    message = conn(:post, "/hello/world", foo: :bar) |> call_and_capture_log(MyPlug)

    assert message =~ "method=POST"
    assert message =~ "path=/hello/world"
    assert message =~ ~s(params={"foo":"bar"})
    assert message =~ "status=200"
    assert message =~ ~r/duration=\d+.\d{3}/u
    assert message =~ "state=set"
  end

  test "handles params with spaces" do
    message = conn(:post, "/hello/world", foo: "one two three") |> call_and_capture_log(MyPlug)

    assert message =~ ~s(params={"foo":"one two three"})
  end

  test "supports non-printable ascii params" do
    message = conn(:get, "/?v=ok…ok") |> call_and_capture_log(MyPlug)

    assert message =~ "ok…ok"
  end

  test "logs file upload params" do
    message =
      conn(:post, "/hello/world",
        upload: %Plug.Upload{content_type: "image/png", filename: "blah.png"}
      )
      |> call_and_capture_log(MyPlug)

    assert message =~
             ~s(params={"upload":{"content_type":"image/png","filename":"blah.png","path":null})
  end

  test "logs phoenix related attributes if present" do
    message = conn(:get, "/") |> call_and_capture_log(MyPlug)

    assert message =~ "method=GET"
    assert message =~ "path=/"
    assert message =~ "params={}"
    assert message =~ "status=200"
    assert message =~ ~r/duration=\d+.\d{3}/u
    assert message =~ "state=set"
  end

  test "filters parameters from the log" do
    message =
      conn(:post, "/hello/world", password: :bar, foo: [password: :other])
      |> call_and_capture_log(MyPlug)

    assert message =~ ~s("password":"[FILTERED]")
    assert message =~ ~s("foo":{"password":"[FILTERED]"})
  end

  test "logs paths with double slashes and trailing slash" do
    message = conn(:get, "/hello/world") |> put_phoenix_privates |> call_and_capture_log(MyPlug)

    assert message =~ "format=json"
    assert message =~ "controller=Logster.Plugs.LoggerTest"
    assert message =~ "action=show"
  end

  test "logs chunked if chunked reply" do
    message = conn(:get, "/hello/world") |> call_and_capture_log(MyChunkedPlug)

    assert message =~ "state=set_chunked"
  end

  test "logs halted connections if :log_on_halt is true" do
    message = conn(:get, "/foo") |> call_and_capture_log(MyHaltingPlug)

    assert message =~ "Logster.Plugs.LoggerTest.MyHaltingPlug halted in :halter/2"
  end

  test "logs params even when they are structs" do
    message = conn(:get, "/hello/world") |> call_and_capture_log(MyStructParamsPlug)

    assert message =~ "params={\"age\":27,\"name\":\"John\"}"
  end

  test "logs params with inspect when a map is not encodeable as json" do
    message = conn(:get, "/hello/world") |> call_and_capture_log(MyMapNotJsonablePlug)

    assert message =~ "%{my_tuple: {27}}"
  end

  test "does not log params if the params are not fetched" do
    message = conn(:get, "/hello/world") |> call_and_capture_log(MyUnfetchedParamsPlug)

    assert message =~ "params={}"
  end

  test "logs to json with the JSONFormatter" do
    message = conn(:get, "/good") |> call_and_capture_log(MyJSONPlug)

    json =
      message
      |> String.split()
      |> Enum.at(3)

    decoded = Jason.decode!(json)

    assert %{"path" => "/good"} = decoded

    %{"duration" => duration} = decoded
    assert is_float(duration)
  end

  test "renaming fields" do
    message = conn(:get, "/foo") |> call_and_capture_log(MyRenameFieldsPlug)

    assert message =~ "mystatus=200"
    assert message =~ ~r/responsetime=\d+.\d{3}/u
  end

  test "excluding fields" do
    message = conn(:get, "/foo") |> call_and_capture_log(MyExcludeFieldsPlug)

    refute message =~ "params={}"
  end

  test "[TextFormatter] log headers: no default headers, no output" do
    Application.put_env(:logster, :allowed_headers, [])

    message =
      conn(:post, "/hello/world", [])
      |> put_req_header("x-test-header", "test value")
      |> call_and_capture_log(MyPlug)

    refute message =~ ~s(headers)
  end

  test "[JSONFormatter] log headers: no default headers, no output" do
    Application.put_env(:logster, :allowed_headers, [])

    message =
      conn(:post, "/hello/world", [])
      |> put_req_header("x-test-header", "test value")
      |> call_and_capture_log(MyJSONPlug)

    json =
      message
      |> String.split()
      |> Enum.at(3)

    refute Jason.decode!(json)[:headers]
  end

  test "[TextFormatter] log headers: test values" do
    Application.put_env(:logster, :allowed_headers, ["my-header-one", "my-header-two"])

    message =
      conn(:post, "/hello/world", [])
      |> put_req_header("my-header-one", "test-value-1")
      |> call_and_capture_log(MyPlug)

    assert message =~ ~s("test-value-1")
  end

  test "[JSONFormatter] log headers: test values" do
    Application.put_env(:logster, :allowed_headers, ["my-header-one", "my-header-two"])

    message =
      conn(:post, "/hello/world", [])
      |> put_req_header("my-header-one", "test-value-1")
      |> put_req_header("my-header-three", "test-value-3")
      |> call_and_capture_log(MyJSONPlug)

    json =
      message
      |> String.split()
      |> Enum.at(3)

    headers = Jason.decode!(json)["headers"]

    assert headers["my-header-one"] == "test-value-1"

    refute headers["my-header-two"]
    refute headers["my-header-three"]
  end
end
