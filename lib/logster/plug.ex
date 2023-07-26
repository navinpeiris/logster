defmodule Logster.Plug do
  @moduledoc """
  A plug for logging request information in the format:

      method=GET path=/articles/some-article format=html controller=HelloPhoenix.ArticleController action=show params={"id":"some-article"} status=200 duration=0.402 state=set

  To use it, just plug it into the desired module.

      plug Logster.Plug, log: :debug

  ## Options

    * `:log` - The log level at which this plug should log its request info.
      Default is `:info`.
  """

  require Logger
  alias Plug.Conn

  def init(opts), do: opts

  def call(conn, opts) do
    start_time = :erlang.monotonic_time()

    Conn.register_before_send(conn, fn conn ->
      duration = :erlang.monotonic_time() - start_time

      Logster.log_conn(
        Logster.log_level(opts[:log], conn),
        conn,
        duration
      )

      conn
    end)
  end
end
