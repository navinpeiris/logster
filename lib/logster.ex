defmodule Logster do
  @moduledoc """
  Single line, easy to parse logs for Elixir Phoenix and Plug applications.

  See the [README](README.md) for more information and configuration options.
  """

  require Logger

  @default_filter_parameters ~w(password)

  # Taken from `Logger` module
  @levels [:emergency, :alert, :critical, :error, :warning, :notice, :info, :debug]

  @type fields_or_message_or_func :: Keyword.t() | Logger.message() | (-> Keyword.t())

  @spec levels() :: list(Logger.level())
  def levels, do: @levels

  for level <- @levels do
    @doc """
    Logs a #{level} message. See `Logster.log/3` for more information.

    Returns `:ok`.
    """
    @spec unquote(level)(fields_or_message_or_func :: fields_or_message_or_func()) :: :ok
    @spec unquote(level)(
            fields_or_message_or_func :: fields_or_message_or_func(),
            metadata :: Logger.metadata()
          ) :: :ok
    def unquote(level)(fields_or_message_or_func, metadata \\ [])

    def unquote(level)(func, metadata) when is_function(func),
      do: Logger.unquote(level)(fn -> formatter().format(func.()) end, metadata)

    def unquote(level)(fields_or_message, metadata),
      do: Logger.unquote(level)(fn -> formatter().format(fields_or_message) end, metadata)
  end

  @doc """
  Logs a message with the given `level`.

  If given an enumerable, the enumerable will be formatted using the configured formatter.

  Returns `:ok`.

  ## Example

  ```
  Logster.log(:info, service: "payment-processor", event: "start-processing", customer: "1234")
  ```

  will produce the following log entry when using the `logfmt` formatter:

  ```
  16:54:29.919 [info] service=payment-processor event=start-processing customer=1234
  ```
  """

  @spec log(
          level :: Logger.level(),
          fields_or_message_or_func :: fields_or_message_or_func()
        ) :: :ok

  @spec log(
          level :: Logger.level(),
          fields_or_message_or_func :: fields_or_message_or_func(),
          metadata :: Logger.metadata()
        ) :: :ok

  def log(level, fields_or_message_or_func, metadata \\ [])

  for level <- @levels do
    def log(unquote(level), fields_or_message_or_func, metadata),
      do: unquote(level)(fields_or_message_or_func, metadata)
  end

  @doc """
  Logs details about the given `conn`

  See the module documentation for more information on configuration options.

  Returns `:ok`.
  """
  @spec log_conn(conn :: Plug.Conn.t(), duration_us :: integer()) :: :ok
  @spec log_conn(conn :: Plug.Conn.t(), duration_us :: integer(), opts :: Keyword.t()) :: :ok

  def log_conn(conn, duration_us, opts \\ [])

  def log_conn(conn, duration_us, nil), do: log_conn(conn, duration_us, [])

  def log_conn(conn, duration_us, opts),
    do: do_log_conn(conn, duration_us, log_config(conn, opts))

  defp do_log_conn(_conn, _duration_us, %{log: false}), do: :ok

  defp do_log_conn(conn, duration_us, log_config) do
    log(
      log_level(conn, log_config),
      fn -> conn |> get_conn_fields(duration_us, log_config) end
    )
  end

  defp formatter(formatter \\ Application.get_env(:logster, :formatter, :logfmt))
  defp formatter(:string), do: Logster.Formatters.Logfmt
  defp formatter(:logfmt), do: Logster.Formatters.Logfmt
  defp formatter(:json), do: Logster.Formatters.JSON
  defp formatter(module), do: module

  defp log_config(conn, opts) do
    conn_log_config =
      conn
      |> Map.get(:private, %{})
      |> Map.get(:logster, [])
      |> Enum.into(%{})

    %{
      status_2xx_level: Application.get_env(:logster, :status_2xx_level, :info),
      status_3xx_level: Application.get_env(:logster, :status_3xx_level, :info),
      status_4xx_level: Application.get_env(:logster, :status_4xx_level, :warning),
      status_5xx_level: Application.get_env(:logster, :status_5xx_level, :error),
      headers: Application.get_env(:logster, :headers, []),
      extra_fields: Application.get_env(:logster, :extra_fields, []),
      excludes: Application.get_env(:logster, :excludes, []),
      renames: Application.get_env(:logster, :renames, []),
      filter_parameters:
        Application.get_env(:logster, :filter_parameters, @default_filter_parameters)
    }
    |> Map.merge(conn_log_config)
    |> Map.merge(opts |> Enum.into(%{}))
  end

  defp log_level(_conn, %{log: level}) when is_atom(level), do: level

  defp log_level(conn, %{log: {mod, fun, args}})
       when is_atom(mod) and is_atom(fun) and is_list(args),
       do: apply(mod, fun, [conn | args])

  defp log_level(%{status: status}, %{status_5xx_level: level})
       when is_integer(status) and status >= 500,
       do: level

  defp log_level(%{status: status}, %{status_4xx_level: level})
       when is_integer(status) and status >= 400,
       do: level

  defp log_level(%{status: status}, %{status_3xx_level: level})
       when is_integer(status) and status >= 300,
       do: level

  defp log_level(%{status: status}, %{status_2xx_level: level})
       when is_integer(status) and status >= 200,
       do: level

  defp log_level(_conn, _log_config), do: :info

  @spec get_conn_fields(conn :: Plug.Conn.t(), duration_us :: integer()) :: list
  @doc false
  def get_conn_fields(%Plug.Conn{} = conn, duration_us),
    do: get_conn_fields(conn, duration_us, log_config(conn, []))

  @doc false
  defp get_conn_fields(%Plug.Conn{} = conn, duration_us, log_config) do
    # We use `Keyword.put` to add items to the list, which prepends items to the list, and so we
    # add items in reverse order of how we want them to appear in the log message.
    []
    |> maybe_put_duration(duration_us, log_config)
    |> maybe_put_headers(conn, log_config)
    |> maybe_put_status(conn, log_config)
    |> maybe_put_query_params(conn, log_config)
    |> maybe_put_params(conn, log_config)
    |> maybe_put_phoenix_action(conn, log_config)
    |> maybe_put_phoenix_controller(conn, log_config)
    |> maybe_put_path(conn, log_config)
    |> maybe_put_method(conn, log_config)
    |> maybe_put_host(conn, log_config)
    |> maybe_put_state(conn, log_config)
    |> maybe_rename_fields(log_config)
  end

  defp maybe_put_duration(fields, duration_us, %{excludes: excludes}) do
    if :duration in excludes do
      fields
    else
      fields |> Keyword.put(:duration, format_duration(duration_us))
    end
  end

  defp format_duration(duration) do
    microseconds = duration |> System.convert_time_unit(:native, :microsecond)
    microseconds / 1000
  end

  defp maybe_put_headers(fields, _conn, %{headers: []}), do: fields

  defp maybe_put_headers(fields, conn, %{headers: log_headers}) do
    headers =
      conn.req_headers
      |> Enum.filter(fn {k, _} -> Enum.member?(log_headers, k) end)
      |> Enum.into(%{}, fn {k, v} -> {k, v} end)

    fields |> Keyword.put(:headers, headers)
  end

  defp maybe_put_status(fields, %{status: status}, %{excludes: excludes}) do
    if :status in excludes do
      fields
    else
      fields |> Keyword.put(:status, status)
    end
  end

  defp maybe_put_query_params(fields, conn, %{extra_fields: extra_fields} = log_config) do
    if :query_params in extra_fields do
      fields |> do_put_query_params(conn, log_config)
    else
      fields
    end
  end

  defp do_put_query_params(fields, %Plug.Conn{query_params: %Plug.Conn.Unfetched{}}, _log_config),
    do: fields |> Keyword.put(:query_params, "[UNFETCHED]")

  defp do_put_query_params(fields, %Plug.Conn{query_params: query_params}, log_config),
    do: do_put_query_params(fields, query_params, log_config)

  defp do_put_query_params(fields, query_params, log_config) do
    query_params =
      query_params
      |> filter_values(log_config)
      |> format_values()

    fields |> Keyword.put(:query_params, query_params)
  end

  defp maybe_put_params(fields, conn, %{excludes: excludes} = log_config) do
    if :params in excludes do
      fields
    else
      fields |> do_put_params(conn, log_config)
    end
  end

  defp do_put_params(fields, %Plug.Conn{params: %Plug.Conn.Unfetched{}}, _log_config),
    do: fields |> Keyword.put(:params, "[UNFETCHED]")

  defp do_put_params(fields, %Plug.Conn{params: params}, log_config),
    do: do_put_params(fields, params, log_config)

  defp do_put_params(fields, params, log_config) do
    params =
      params
      |> filter_values(log_config)
      |> format_values()

    fields |> Keyword.put(:params, params)
  end

  defp maybe_put_phoenix_action(fields, %Plug.Conn{private: %{phoenix_action: action}}, %{
         excludes: excludes
       }) do
    if :action in excludes do
      fields
    else
      fields |> Keyword.put(:action, Atom.to_string(action))
    end
  end

  defp maybe_put_phoenix_action(fields, _, _), do: fields

  defp maybe_put_phoenix_controller(
         fields,
         %Plug.Conn{private: %{phoenix_controller: controller}},
         %{
           excludes: excludes
         }
       ) do
    if :controller in excludes do
      fields
    else
      fields |> Keyword.put(:controller, inspect(controller))
    end
  end

  defp maybe_put_phoenix_controller(fields, _, _), do: fields

  defp maybe_put_path(fields, %Plug.Conn{request_path: path}, %{excludes: excludes}) do
    if :path in excludes do
      fields
    else
      fields |> Keyword.put(:path, path)
    end
  end

  defp maybe_put_method(fields, %Plug.Conn{method: method}, %{excludes: excludes}) do
    if :method in excludes do
      fields
    else
      fields |> Keyword.put(:method, method)
    end
  end

  defp maybe_put_host(fields, %Plug.Conn{host: host}, %{extra_fields: extra_fields}) do
    if :host in extra_fields do
      fields |> Keyword.put(:host, host)
    else
      fields
    end
  end

  defp maybe_put_state(fields, %Plug.Conn{state: state}, %{excludes: excludes}) do
    if :state in excludes do
      fields
    else
      fields |> Keyword.put(:state, format_state(state))
    end
  end

  defp format_state(:set_chunked), do: "chunked"
  defp format_state(_), do: "sent"

  defp maybe_rename_fields(fields, %{renames: []}), do: fields

  defp maybe_rename_fields(fields, %{renames: renames}) do
    renames_map = renames |> Enum.into(%{})

    fields
    |> Enum.map(fn {key, value} ->
      if new_key = Map.get(renames_map, key) do
        {new_key, value}
      else
        {key, value}
      end
    end)
  end

  defp filter_values(params, %{filter_parameters: filter_parameters}),
    do: do_filter_values(params, filter_parameters)

  defp do_filter_values(params, {:discard, discard_params}),
    do: discard_values(params, discard_params)

  defp do_filter_values(params, {:keep, keep_params}), do: keep_values(params, keep_params)
  defp do_filter_values(params, filtered_params), do: discard_values(params, filtered_params)

  defp discard_values(%{__struct__: mod} = struct, filter_config) when is_atom(mod) do
    struct
    |> Map.from_struct()
    |> Enum.map(fn {k, v} -> {Atom.to_string(k), v} end)
    |> Enum.into(%{})
    |> discard_values(filter_config)
  end

  defp discard_values(%{} = map, discard_params) do
    Enum.into(map, %{}, fn {k, v} ->
      if is_binary(k) and String.contains?(k, discard_params) do
        {k, "[FILTERED]"}
      else
        {k, discard_values(v, discard_params)}
      end
    end)
  end

  defp discard_values([_ | _] = list, discard_params),
    do: Enum.map(list, &discard_values(&1, discard_params))

  defp discard_values(other, _discard_params), do: other

  defp keep_values(%{__struct__: mod}, _keep_params) when is_atom(mod), do: "[FILTERED]"

  defp keep_values(%{} = map, keep_params) do
    Enum.into(map, %{}, fn {k, v} ->
      if is_binary(k) and k in keep_params do
        {k, discard_values(v, [])}
      else
        {k, keep_values(v, keep_params)}
      end
    end)
  end

  defp keep_values([_ | _] = list, keep_params), do: Enum.map(list, &keep_values(&1, keep_params))

  defp keep_values(_other, _keep_params), do: "[FILTERED]"

  defp format_values(params), do: params |> Enum.into(%{}, &format_value/1)

  defp format_value({key, value}) when is_binary(value) do
    if String.valid?(value) do
      {key, value}
    else
      {key, URI.encode(value)}
    end
  end

  defp format_value(val), do: val

  #
  # Phoenix
  #

  @phoenix_handler_id {__MODULE__, :phoenix}

  @doc """
  Attaches a telemetry handler to the `:phoenix` event stream for logging.

  Returns `:ok`.
  """
  @spec attach_phoenix_logger :: :ok
  def attach_phoenix_logger do
    events = [
      [:phoenix, :endpoint, :stop],
      [:phoenix, :socket_connected],
      [:phoenix, :channel_joined],
      [:phoenix, :channel_handled_in]
    ]

    :telemetry.attach_many(
      @phoenix_handler_id,
      events,
      &__MODULE__.handle_phoenix_event/4,
      :ok
    )
  end

  @doc """
  Detaches logster's telemetry handler from the `:phoenix` event stream.

  Returns `:ok`.
  """
  @spec detach_phoenix_logger :: :ok
  def detach_phoenix_logger, do: :telemetry.detach(@phoenix_handler_id)

  @doc false
  def handle_phoenix_event(
        [:phoenix, :endpoint, :stop],
        %{duration: duration},
        %{conn: conn} = metadata,
        _
      ),
      do: conn |> log_conn(duration, metadata[:options])

  @doc false
  def handle_phoenix_event([:phoenix, :socket_connected], _, %{log: false}, _), do: :ok

  @doc false
  def handle_phoenix_event(
        [:phoenix, :socket_connected],
        %{duration: duration},
        %{log: level} = meta,
        _
      ) do
    log(level, fn ->
      %{
        transport: transport,
        params: params,
        user_socket: user_socket,
        result: result,
        serializer: serializer
      } = meta

      [
        action: :connect,
        state: result,
        socket: inspect(user_socket),
        duration: format_duration(duration),
        transport: Atom.to_string(transport),
        serializer: inspect(serializer)
      ]
      |> append_params(params)
    end)
  end

  @doc false
  def handle_phoenix_event(
        [:phoenix, :channel_joined],
        %{duration: duration},
        %{socket: socket} = metadata,
        _
      ) do
    channel_log(:log_join, socket, fn ->
      %{result: result, params: params} = metadata

      [
        action: :join,
        state: result,
        topic: socket.topic,
        duration: format_duration(duration)
      ]
      |> append_params(params)
    end)
  end

  @doc false
  def handle_phoenix_event(
        [:phoenix, :channel_handled_in],
        %{duration: duration},
        %{socket: socket} = metadata,
        _
      ) do
    channel_log(:log_handle_in, socket, fn ->
      %{event: event, params: params} = metadata

      [
        action: :handled,
        event: event,
        topic: socket.topic,
        channel: inspect(socket.channel),
        duration: format_duration(duration)
      ]
      |> append_params(params)
    end)
  end

  defp channel_log(_log_option, %{topic: "phoenix" <> _}, _fun), do: :ok

  defp channel_log(log_option, %{private: private}, fun) do
    if level = Map.get(private, log_option) do
      log(level, fun)
    end
  end

  defp append_params(fields, params),
    do: fields ++ maybe_put_params([], params, log_config(%{}, []))
end
