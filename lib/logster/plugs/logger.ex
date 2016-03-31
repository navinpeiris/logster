defmodule Logster.Plugs.Logger do
  @moduledoc """
  A plug for logging request information in the format:

      method=GET path=/articles/some-article format=html controller=HelloPhoenix.ArticleController action=show params={"id":"some-article"} status=200 duration=0.402 state=set

  To use it, just plug it into the desired module.

      plug Logster.Plugs.Logger, log: :debug

  For Phoenix applications, replace `Plug.Logger` with `Logster.Plugs.Logger` in the `endpoint.ex` file:

      # plug Plug.Logger
      plug Logster.Plugs.Logger

  ## Options

    * `:log` - The log level at which this plug should log its request info.
      Default is `:info`.
  """

  require Logger
  alias Plug.Conn

  @default_filter_parameters ~w(password)

  def init(opts) do
    Keyword.get(opts, :log, :info)
  end

  def call(conn, config_log_level) do
    start_time = current_time

    Conn.register_before_send(conn, fn conn ->
      Logger.log log_level(conn, config_log_level), fn ->
        stop_time = current_time
        duration = time_diff(start_time, stop_time)

        [
          formatted_info("method", conn.method),
          formatted_info("path", conn.request_path),
          formatted_phoenix_info(conn),
          formatted_info("params", conn.params |> filter_params |> Poison.encode!),
          formatted_info("status", conn.status |> Integer.to_string),
          formatted_info("duration", formatted_duration(duration)),
          formatted_info("state", conn.state |> Atom.to_string, "")
        ]
      end
      conn
    end)
  end

  defp current_time, do: :erlang.monotonic_time
  defp time_diff(start, stop), do: (stop - start) |> :erlang.convert_time_unit(:native, :micro_seconds)

  defp formatted_duration(duration), do: duration / 1000 |> Float.to_string(decimals: 3)

  defp formatted_phoenix_info(%{private: %{phoenix_format: format, phoenix_controller: controller, phoenix_action: action}}) do
    [
      formatted_info("format", format),
      formatted_info("controller", controller |> inspect),
      formatted_info("action", action |> Atom.to_string)
    ]
  end
  defp formatted_phoenix_info(_), do: []

  defp filter_params(%{} = params) do
    Enum.into params, %{}, fn {k, v} ->
      if is_binary(k) && String.contains?(k, params_to_filter) do
        {k, "[FILTERED]"}
      else
        {k, filter_params(v)}
      end
    end
  end
  defp filter_params(params), do: params

  defp formatted_info(name, value, postfix \\ ?\s), do: [name, "=", value, postfix]
  defp params_to_filter, do: Application.get_env(:logster, :filter_parameters, @default_filter_parameters)

  defp log_level(%{private: %{logster_log_level: logster_log_level}}, _config_log_level), do: logster_log_level
  defp log_level(_, config_log_level), do: config_log_level
end
