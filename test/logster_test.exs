defmodule Logster.Test do
  use Logster.Case, async: false

  import ExUnit.CaptureLog

  def log_as_debug(_), do: :debug

  test "can attach and detach phoenix logger" do
    :ok = Logster.attach_phoenix_logger()
    :ok = Logster.detach_phoenix_logger()
  end

  for level <- Logster.levels() do
    describe "#{level}/2" do
      test "logs formatted message when given a keyword list" do
        message =
          capture_log(fn ->
            Logster.unquote(level)([service: :payments, status: :processing, customer: "123"],
              one: "two"
            )
          end)

        assert message =~
                 "[#{unquote(level)}] service=payments status=processing customer=123"
      end

      test "logs message when given a binary" do
        message =
          capture_log(fn ->
            Logster.unquote(level)("something happened", one: "two")
          end)

        assert message =~ "[#{unquote(level)}] something happened"
      end

      test "logs message when given a list" do
        message =
          capture_log(fn ->
            Logster.unquote(level)(["something", "happened"], one: "two")
          end)

        assert message =~ "[#{unquote(level)}] something happened"
      end

      test "logs result when given a function" do
        message =
          capture_log(fn ->
            Logster.unquote(level)(fn -> [service: :payments, status: :processing] end)
          end)

        assert message =~ "[#{unquote(level)}] service=payments status=processing"
      end
    end
  end

  describe "log/3 with default formatter" do
    test "logs formatted message when given a keyword list" do
      message =
        capture_log(fn ->
          Logster.log(:info, [service: :payments, status: :processing, customer: "123"],
            one: "two"
          )
        end)

      assert message =~ "[info] service=payments status=processing customer=123"
    end

    test "logs message when given a binary" do
      message =
        capture_log(fn ->
          Logster.log(:warning, "something happened", one: "two")
        end)

      assert message =~ "[warning] something happened"
    end

    test "logs message when given a list" do
      message =
        capture_log(fn ->
          Logster.log(:error, ["something", "happened"], one: "two")
        end)

      assert message =~ "[error] something happened"
    end

    test "logs result when given a function" do
      message =
        capture_log(fn ->
          Logster.log(:debug, fn -> [service: :payments, status: :processing] end, one: "two")
        end)

      assert message =~ "[debug] service=payments status=processing"
    end
  end

  describe "log/3 with formatter module given" do
    @tag with_config: [formatter: Logster.Formatters.String]
    test "logs formatted message when given a keyword list" do
      message =
        capture_log(fn ->
          Logster.log(:info, [service: :payments, status: :processing, customer: "123"],
            one: "two"
          )
        end)

      assert message =~ "[info] service=payments status=processing customer=123"
    end
  end

  describe "log/3 with json formatter" do
    @tag with_config: [formatter: :json]
    test "logs formatted message when given a keyword list" do
      message =
        capture_log(fn ->
          Logster.log(:info, [service: :payments, status: :processing, customer: "123"],
            one: "two"
          )
        end)

      assert message =~ ~s([info] {"status":"processing","service":"payments","customer":"123"})
    end

    @tag with_config: [formatter: :json]
    test "logs message when given a binary" do
      message =
        capture_log(fn ->
          Logster.log(:warning, "something happened", one: "two")
        end)

      assert message =~ ~s([warning] {"msg":"something happened"})
    end

    @tag with_config: [formatter: :json]
    test "logs message when given a list" do
      message =
        capture_log(fn ->
          Logster.log(:error, ["something", "happened"], one: "two")
        end)

      assert message =~ ~s([error] {"msg":["something","happened"]})
    end

    @tag with_config: [formatter: :json]
    test "logs result when given a function" do
      message =
        capture_log(fn ->
          Logster.log(:debug, fn -> [service: :payments, status: :processing] end, one: "two")
        end)

      assert message =~ ~s([debug] {"status":"processing","service":"payments"})
    end
  end

  describe "log_conn/3" do
    test "logs conn details in the given log level" do
      conn = %Plug.Conn{
        method: "GET",
        request_path: "/hello/world",
        params: %{"foo" => "bar"},
        status: 200
      }

      message =
        capture_log(fn ->
          Logster.log_conn(:info, conn, 123_456, one: "two")
        end)

      assert message =~
               ~s([info] state=sent method=GET path=/hello/world params={"foo":"bar"} status=200 duration=0.123)
    end
  end

  describe "telemetry event handling for phoenix requests" do
    setup do
      key = [:phoenix, :endpoint, :stop]

      :ok = :telemetry.attach({Logster.Test, key}, key, &Logster.handle_phoenix_event/4, :ok)

      on_exit(fn ->
        :ok = :telemetry.detach({Logster.Test, key})
      end)
    end

    test "logs info level message when the status is 2xx" do
      conn = %Plug.Conn{
        method: "GET",
        request_path: "/hello/world",
        params: %{"foo" => "bar"},
        status: 200
      }

      message =
        capture_log(fn ->
          :telemetry.execute([:phoenix, :endpoint, :stop], %{duration: 123_456}, %{conn: conn})
        end)

      assert message =~
               ~s([info] state=sent method=GET path=/hello/world params={"foo":"bar"} status=200 duration=0.123)
    end

    test "logs info level message when the status is 3xx" do
      conn = %Plug.Conn{
        method: "GET",
        request_path: "/hello/world",
        params: %{"foo" => "bar"},
        status: 301
      }

      message =
        capture_log(fn ->
          :telemetry.execute([:phoenix, :endpoint, :stop], %{duration: 123_456}, %{conn: conn})
        end)

      assert message =~
               ~s([info] state=sent method=GET path=/hello/world params={"foo":"bar"} status=301 duration=0.123)
    end

    test "logs warning level message when the status is 4xx" do
      conn = %Plug.Conn{
        method: "GET",
        request_path: "/hello/world",
        params: %{"foo" => "bar"},
        status: 400
      }

      message =
        capture_log(fn ->
          :telemetry.execute([:phoenix, :endpoint, :stop], %{duration: 123_456}, %{conn: conn})
        end)

      assert message =~
               ~s([warning] state=sent method=GET path=/hello/world params={"foo":"bar"} status=400 duration=0.123)
    end

    test "logs error level message when the status is 5xx" do
      conn = %Plug.Conn{
        method: "GET",
        request_path: "/hello/world",
        params: %{"foo" => "bar"},
        status: 500
      }

      message =
        capture_log(fn ->
          :telemetry.execute([:phoenix, :endpoint, :stop], %{duration: 123_456}, %{conn: conn})
        end)

      assert message =~
               ~s([error] state=sent method=GET path=/hello/world params={"foo":"bar"} status=500 duration=0.123)
    end

    test "logs at given level when the log option is provided" do
      conn = %Plug.Conn{
        method: "GET",
        request_path: "/hello/world",
        params: %{"foo" => "bar"},
        status: 200
      }

      message =
        capture_log(fn ->
          :telemetry.execute([:phoenix, :endpoint, :stop], %{duration: 123_456}, %{
            conn: conn,
            options: [log: :warning]
          })
        end)

      assert message =~
               ~s([warning] state=sent method=GET path=/hello/world params={"foo":"bar"} status=200 duration=0.123)
    end

    test "logs at given level when the log level function is provided" do
      conn = %Plug.Conn{
        method: "GET",
        request_path: "/hello/world",
        params: %{"foo" => "bar"},
        status: 200
      }

      message =
        capture_log(fn ->
          :telemetry.execute([:phoenix, :endpoint, :stop], %{duration: 123_456}, %{
            conn: conn,
            options: [log: {Logster.Test, :log_as_debug, []}]
          })
        end)

      assert message =~
               ~s([debug] state=sent method=GET path=/hello/world params={"foo":"bar"} status=200 duration=0.123)
    end

    test "logs at given level when change log level plug is called" do
      conn =
        %Plug.Conn{
          method: "GET",
          request_path: "/hello/world",
          params: %{"foo" => "bar"},
          status: 200
        }
        |> Logster.ChangeLogLevel.call(Logster.ChangeLogLevel.init(to: :warning))

      message =
        capture_log(fn ->
          :telemetry.execute([:phoenix, :endpoint, :stop], %{duration: 123_456}, %{conn: conn})
        end)

      assert message =~
               ~s([warning] state=sent method=GET path=/hello/world params={"foo":"bar"} status=200 duration=0.123)
    end

    test "does not log when log option is false" do
      conn = %Plug.Conn{
        method: "GET",
        request_path: "/hello/world",
        params: %{"foo" => "bar"},
        status: 200
      }

      message =
        capture_log(fn ->
          :telemetry.execute([:phoenix, :endpoint, :stop], %{duration: 123_456}, %{
            conn: conn,
            options: [log: false]
          })
        end)

      assert message == ""
    end
  end

  describe "telemetry event handling for phoenix socket connected" do
    setup do
      key = [:phoenix, :socket_connected]

      :ok = :telemetry.attach({Logster.Test, key}, key, &Logster.handle_phoenix_event/4, :ok)

      on_exit(fn ->
        :ok = :telemetry.detach({Logster.Test, key})
      end)
    end

    test "logs at provided log level" do
      meta = %{
        transport: :websocket,
        params: %{"foo" => "bar"},
        user_socket: Logster.Socket,
        result: :ok,
        serializer: Logster.Serializer,
        log: :info
      }

      message =
        capture_log(fn ->
          :telemetry.execute([:phoenix, :socket_connected], %{duration: 123_456}, meta)
        end)

      assert message =~
               ~s([info] action=connect state=ok socket=Logster.Socket duration=0.123 transport=websocket serializer=Logster.Serializer params={"foo":"bar"})
    end

    test "does not log when log is false" do
      meta = %{
        transport: :websocket,
        params: %{"foo" => "bar"},
        user_socket: Logster.Socket,
        result: :ok,
        serializer: Logster.Serializer,
        log: false
      }

      message =
        capture_log(fn ->
          :telemetry.execute([:phoenix, :socket_connected], %{duration: 123_456}, meta)
        end)

      assert message == ""
    end
  end

  describe "telemetry event handling for phoenix channel joined" do
    setup do
      key = [:phoenix, :channel_joined]

      :ok = :telemetry.attach({Logster.Test, key}, key, &Logster.handle_phoenix_event/4, :ok)

      on_exit(fn ->
        :ok = :telemetry.detach({Logster.Test, key})
      end)
    end

    test "logs at specified log level" do
      meta = %{
        socket: %{
          topic: "room:lobby",
          private: %{
            log_join: :info
          }
        },
        result: :ok,
        params: %{"foo" => "bar"}
      }

      message =
        capture_log(fn ->
          :telemetry.execute([:phoenix, :channel_joined], %{duration: 123_456}, meta)
        end)

      assert message =~
               ~s([info] action=join state=ok topic=room:lobby duration=0.123 params={"foo":"bar"})
    end

    test "does not log phoenix topic events" do
      meta = %{
        socket: %{
          topic: "phoenix:topic",
          private: %{
            log_join: :info
          }
        },
        result: :ok,
        params: %{"foo" => "bar"}
      }

      message =
        capture_log(fn ->
          :telemetry.execute([:phoenix, :channel_joined], %{duration: 123_456}, meta)
        end)

      assert message == ""
    end
  end

  describe "telemetry event handling for phoenix channel handle in" do
    setup do
      key = [:phoenix, :channel_handled_in]

      :ok = :telemetry.attach({Logster.Test, key}, key, &Logster.handle_phoenix_event/4, :ok)

      on_exit(fn ->
        :ok = :telemetry.detach({Logster.Test, key})
      end)
    end

    test "logs at specified log level" do
      meta = %{
        socket: %{
          topic: "room:lobby",
          channel: Logster.Channel,
          private: %{
            log_handle_in: :info
          }
        },
        event: "event",
        params: %{"foo" => "bar"}
      }

      message =
        capture_log(fn ->
          :telemetry.execute([:phoenix, :channel_handled_in], %{duration: 123_456}, meta)
        end)

      assert message =~
               ~s( [info] action=handled event=event topic=room:lobby channel=Logster.Channel duration=0.123 params={"foo":"bar"})
    end

    test "does not log phoenix topic events" do
      meta = %{
        socket: %{
          topic: "phoenix:lobby",
          channel: Logster.Channel,
          private: %{
            log_handle_in: :info
          }
        },
        event: "event",
        params: %{"foo" => "bar"}
      }

      message =
        capture_log(fn ->
          :telemetry.execute([:phoenix, :channel_handled_in], %{duration: 123_456}, meta)
        end)

      assert message == ""
    end
  end

  describe "get_conn_fields/1" do
    defmodule TestStruct do
      defstruct [:name, :password]
    end

    defmodule TestFilterParamStruct do
      defstruct [:one, :foo, :fi]
    end

    def test_filter_params do
      %{
        "one" => "two",
        "foo" => "bar",
        "fi" => "fo",
        "map" => %{
          "one" => "two",
          "foo" => "bar",
          "fi" => "fo"
        },
        "list" => [
          %{
            "one" => "two",
            "foo" => "bar",
            "fi" => "fo"
          },
          %{
            "one" => "two",
            "foo" => "bar",
            "fi" => "fo"
          }
        ],
        "struct" => %TestFilterParamStruct{
          one: "two",
          foo: "bar",
          fi: "fo"
        }
      }
    end

    test "extracts base fields from conn" do
      fields =
        %Plug.Conn{
          state: :set,
          method: "POST",
          request_path: "/some/test/path",
          status: 201
        }
        |> Logster.get_conn_fields()

      assert {:state, "sent"} in fields
      assert {:method, "POST"} in fields
      assert {:path, "/some/test/path"} in fields
      assert {:status, 201} in fields
    end

    test "sets state to chunked when state is set_chunked" do
      fields =
        %Plug.Conn{
          state: :set_chunked
        }
        |> Logster.get_conn_fields()

      assert {:state, "chunked"} in fields
    end

    test "adds phoenix controller information if present" do
      fields =
        %Plug.Conn{
          private: %{
            :phoenix_controller => Logster.TestController,
            :phoenix_action => :show
          }
        }
        |> Logster.get_conn_fields()

      assert {:controller, "Logster.TestController"} in fields
      assert {:action, "show"} in fields
    end

    test "sets params as unfetched" do
      fields =
        %Plug.Conn{
          params: %Plug.Conn.Unfetched{}
        }
        |> Logster.get_conn_fields()

      assert {:params, "[UNFETCHED]"} in fields
    end

    test "adds params" do
      fields =
        %Plug.Conn{
          params: %{
            "one" => "two",
            "foo" => "bar"
          }
        }
        |> Logster.get_conn_fields()

      assert {:params,
              %{
                "one" => "two",
                "foo" => "bar"
              }} in fields
    end

    test "filters password params by default" do
      fields =
        %Plug.Conn{
          params: %{
            "one" => "two",
            "password" => "should-not-show",
            "secret" => "should-show"
          }
        }
        |> Logster.get_conn_fields()

      assert {:params,
              %{
                "one" => "two",
                "password" => "[FILTERED]",
                "secret" => "should-show"
              }} in fields
    end

    @tag with_config: [filter_parameters: []]
    test "does not filter password if configured not to" do
      fields =
        %Plug.Conn{
          params: %{
            "one" => "two",
            "password" => "should-show",
            "secret" => "should-show"
          }
        }
        |> Logster.get_conn_fields()

      assert {:params,
              %{
                "one" => "two",
                "password" => "should-show",
                "secret" => "should-show"
              }} in fields
    end

    @tag with_config: [filter_parameters: ~w(password secret)]
    test "filters all parameters specified in config" do
      fields =
        %Plug.Conn{
          params: %{
            "one" => "two",
            "password" => "should-not-show",
            "secret" => "should-not-show"
          }
        }
        |> Logster.get_conn_fields()

      assert {:params,
              %{
                "one" => "two",
                "password" => "[FILTERED]",
                "secret" => "[FILTERED]"
              }} in fields
    end

    @tag with_config: [filter_parameters: ~w(password secret)]
    test "filters nested parameters" do
      fields =
        %Plug.Conn{
          params: %{
            "one" => "two",
            "password" => "should-not-show",
            "user" => %{"name" => "John", "password" => "should-not-show"}
          }
        }
        |> Logster.get_conn_fields()

      assert {:params,
              %{
                "one" => "two",
                "password" => "[FILTERED]",
                "user" => %{"name" => "John", "password" => "[FILTERED]"}
              }} in fields
    end

    @tag with_config: [filter_parameters: {:keep, ~w(one)}]
    test "logs only specified parameters using keep strategy" do
      fields =
        %Plug.Conn{
          params: test_filter_params()
        }
        |> Logster.get_conn_fields()

      assert {:params,
              %{
                "one" => "two",
                "foo" => "[FILTERED]",
                "fi" => "[FILTERED]",
                "list" => [
                  %{
                    "one" => "two",
                    "foo" => "[FILTERED]",
                    "fi" => "[FILTERED]"
                  },
                  %{
                    "one" => "two",
                    "foo" => "[FILTERED]",
                    "fi" => "[FILTERED]"
                  }
                ],
                "map" => %{
                  "one" => "two",
                  "foo" => "[FILTERED]",
                  "fi" => "[FILTERED]"
                },
                "struct" => "[FILTERED]"
              }} in fields
    end

    @tag with_config: [filter_parameters: {:discard, ~w(foo fi)}]
    test "discard specified parameters using discard strategy" do
      fields =
        %Plug.Conn{
          params: test_filter_params()
        }
        |> Logster.get_conn_fields()

      assert {:params,
              %{
                "one" => "two",
                "foo" => "[FILTERED]",
                "fi" => "[FILTERED]",
                "map" => %{
                  "one" => "two",
                  "foo" => "[FILTERED]",
                  "fi" => "[FILTERED]"
                },
                "list" => [
                  %{
                    "one" => "two",
                    "foo" => "[FILTERED]",
                    "fi" => "[FILTERED]"
                  },
                  %{
                    "one" => "two",
                    "foo" => "[FILTERED]",
                    "fi" => "[FILTERED]"
                  }
                ],
                "struct" => %{
                  "one" => "two",
                  "foo" => "[FILTERED]",
                  "fi" => "[FILTERED]"
                }
              }} in fields
    end

    test "supports tuple params" do
      fields =
        %Plug.Conn{
          params: %{
            "tuple" => {"John", "pass"}
          }
        }
        |> Logster.get_conn_fields()

      assert {:params, %{"tuple" => {"John", "pass"}}} in fields
    end

    test "supports non-printable ascii params" do
      fields =
        %Plug.Conn{
          params: %{
            "v" => "ok…ok"
          }
        }
        |> Logster.get_conn_fields()

      assert {:params, %{"v" => "ok…ok"}} in fields
    end

    test "does not add query params if not enabled in config" do
      fields =
        %Plug.Conn{
          query_params: %{"foo" => "bar"}
        }
        |> Logster.get_conn_fields()

      assert fields |> Keyword.has_key?(:query_params) == false
    end

    @tag with_config: [extra_fields: [:query_params]]
    test "sets query params as unfetched when enabled in config" do
      fields =
        %Plug.Conn{
          query_params: %Plug.Conn.Unfetched{}
        }
        |> Logster.get_conn_fields()

      assert {:query_params, "[UNFETCHED]"} in fields
    end

    @tag with_config: [extra_fields: [:query_params]]
    test "adds query params when enabled in config" do
      fields =
        %Plug.Conn{
          query_params: %{
            "one" => "two",
            "foo" => "bar"
          }
        }
        |> Logster.get_conn_fields()

      assert {:query_params,
              %{
                "one" => "two",
                "foo" => "bar"
              }} in fields
    end

    @tag with_config: [extra_fields: [:query_params]]
    test "filters password query params by default" do
      fields =
        %Plug.Conn{
          query_params: %{
            "one" => "two",
            "password" => "should-not-show",
            "secret" => "should-show"
          }
        }
        |> Logster.get_conn_fields()

      assert {:query_params,
              %{
                "one" => "two",
                "password" => "[FILTERED]",
                "secret" => "should-show"
              }} in fields
    end

    test "does not add headers by default" do
      fields =
        %Plug.Conn{
          state: :set_chunked,
          req_headers: [
            {"content-type", "application/json"},
            {"host", "example.com"},
            {"accept", "text/html"}
          ]
        }
        |> Logster.get_conn_fields()

      refute fields |> Keyword.has_key?(:headers)
    end

    @tag with_config: [headers: ["host", "accept"]]
    test "adds headers when set in config" do
      fields =
        %Plug.Conn{
          state: :set_chunked,
          req_headers: [
            {"content-type", "application/json"},
            {"host", "example.com"},
            {"accept", "text/html"}
          ]
        }
        |> Logster.get_conn_fields()

      assert {:headers, %{"host" => "example.com", "accept" => "text/html"}} in fields
    end

    @tag with_config: [extra_fields: [:host]]
    test "includes host when enabled in config" do
      fields =
        %Plug.Conn{
          state: :set,
          method: "POST",
          request_path: "/some/test/path",
          status: 201
        }
        |> Logster.get_conn_fields()

      assert {:host, "www.example.com"} in fields
    end

    @tag with_config: [excludes: [:params, :status, :state]]
    test "excludes fields when set in config" do
      fields =
        %Plug.Conn{
          state: :set,
          method: "POST",
          request_path: "/some/test/path",
          status: 201
        }
        |> Logster.get_conn_fields()

      refute fields |> Keyword.has_key?(:params)
      refute fields |> Keyword.has_key?(:status)
      refute fields |> Keyword.has_key?(:state)

      assert {:method, "POST"} in fields
      assert {:path, "/some/test/path"} in fields
    end

    @tag with_config: [renames: %{status: :mystatus, duration: :responsetime}]
    test "supports renames" do
      fields =
        %Plug.Conn{
          state: :set,
          method: "POST",
          request_path: "/some/test/path",
          status: 201
        }
        |> Logster.get_conn_fields(duration: "0.123")

      refute fields |> Keyword.has_key?(:status)
      refute fields |> Keyword.has_key?(:duration)

      assert {:mystatus, 201} in fields
      assert {:responsetime, "0.123"} in fields
    end
  end
end
