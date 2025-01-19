defmodule Logster.ChangeConfig do
  @moduledoc """
  A plug used to change the logging configuration of Logster. Useful for changing the log level for a specific controller or action.

  To change the configuration for a specific controller, add the following in the controller:

      plug Logster.ChangeConfig, status_2xx_level: :debug, status_4xx_level: :info

  To specify it only for a specific action, add the following:

      plug Logster.ChangeConfig, [status_2xx_level: :debug] when action in [:index, :show]
  """

  @spec init(Keyword.t()) :: Keyword.t()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), Keyword.t()) :: Plug.Conn.t()
  def call(conn, opts), do: conn |> Plug.Conn.put_private(:logster, opts)
end
