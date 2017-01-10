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
  @default_allowed_headers ~w()

  def init(opts) do
    opts
  end

  def call(conn, opts) do
    start_time = current_time()

    Conn.register_before_send(conn, fn conn ->
      Logger.log log_level(conn, opts), fn ->
        formatter = Keyword.get(opts, :formatter, Logster.StringFormatter)
        stop_time = current_time()
        duration = time_diff(start_time, stop_time)
        []
        |> Keyword.put(:method, conn.method)
        |> Keyword.put(:path, conn.request_path)
        |> Keyword.merge(formatted_phoenix_info(conn))
        |> Keyword.put(:params, filter_params(conn.params))
        |> Keyword.put(:status, conn.status)
        |> Keyword.put(:duration, formatted_duration(duration))
        |> Keyword.put(:state, conn.state)
        |> Keyword.merge(headers(conn.req_headers, Application.get_env(:logster, :allowed_headers, @default_allowed_headers)))
        |> Keyword.merge(Logger.metadata())
        |> formatter.format
      end
      conn
    end)
  end

  defp headers(_, []), do: []
  defp headers(conn_headers, allowed_headers) do
    map = conn_headers
    |> Enum.filter(fn({k, _}) -> Enum.member?(allowed_headers, k) end)
    |> Enum.into(%{}, fn {k,v} -> {k,v} end)

    [{:headers, map}]
  end

  defp current_time, do: :erlang.monotonic_time
  defp time_diff(start, stop), do: (stop - start) |> :erlang.convert_time_unit(:native, :micro_seconds)

  defp formatted_duration(duration), do: duration / 1000

  defp formatted_phoenix_info(%{private: %{phoenix_format: format, phoenix_controller: controller, phoenix_action: action}}) do
    [
      {:format, format},
      {:controller, controller |> inspect},
      {:action, action |> Atom.to_string}
    ]
  end
  defp formatted_phoenix_info(_), do: []

  defp filter_params(params), do: do_filter_params(params, Application.get_env(:logster, :filter_parameters, @default_filter_parameters))

  def do_filter_params(%{__struct__: mod} = struct, _params_to_filter) when is_atom(mod), do: struct
  def do_filter_params(%{} = map, params_to_filter) do
    Enum.into map, %{}, fn {k, v} ->
      if is_binary(k) && String.contains?(k, params_to_filter) do
        {k, "[FILTERED]"}
      else
        {k, do_filter_params(v, params_to_filter)}
      end
    end
  end
  def do_filter_params([_|_] = list, params_to_filter), do: Enum.map(list, &do_filter_params(&1, params_to_filter))
  def do_filter_params(other, _params_to_filter), do: other


  defp log_level(%{private: %{logster_log_level: logster_log_level}}, _opts), do: logster_log_level
  defp log_level(_, opts), do: Keyword.get(opts, :log, :info)
end
