defmodule Logster.ChangeLogLevel do
  @moduledoc """
  A plug for changing the log level used by Logster. Useful for increasing/decreasing the log level on a per controller or action basis

  To change the log level for a specific controller, add the following in the controller

    plug Logster.Plugs.ChangeLogLevel, to: :debug

  To specify it only for a specific action, add the following:

    plug Logster.Plugs.ChangeLogLevel, to: :debug when action in [:index, :show]
  """

  import Plug.Conn

  def init(opts), do: Keyword.get(opts, :to, :info)

  def call(conn, log_level), do: conn |> put_private(:logster_log_level, log_level)
end
