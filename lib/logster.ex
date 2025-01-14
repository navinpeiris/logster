defmodule Logster do
  @external_resource readme = Path.join([__DIR__, "../README.md"])

  @moduledoc readme
             |> File.read!()
             |> String.split("<!-- MDOC -->")
             |> Enum.fetch!(1)

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
  Logs details about the given `conn` at the given `level`.

  See the module documentation for more information on configuration options.

  Returns `:ok`.
  """
  @spec log_conn(
          level :: Logger.level(),
          conn :: Plug.Conn.t(),
          duration_us :: integer(),
          metadata :: Logger.metadata()
        ) :: :ok
  def log_conn(level, conn, duration_us, metadata \\ []) do
    log(
      level,
      fn -> conn |> get_conn_fields(duration: format_duration(duration_us)) end,
      metadata
    )
  end

  defp formatter(formatter \\ Application.get_env(:logster, :formatter, :logfmt))
  defp formatter(:string), do: Logster.Formatters.Logfmt
  defp formatter(:logfmt), do: Logster.Formatters.Logfmt
  defp formatter(:json), do: Logster.Formatters.JSON
  defp formatter(module), do: module

  @doc false
  def log_level(_, %{private: %{logster_log_level: level}}), do: level

  def log_level(nil, %{status: status}) when is_integer(status) and status >= 500, do: :error
  def log_level(nil, %{status: status}) when is_integer(status) and status >= 400, do: :warning
  def log_level(nil, _conn), do: :info

  def log_level(level, _conn) when is_atom(level), do: level

  def log_level({mod, fun, args}, conn) when is_atom(mod) and is_atom(fun) and is_list(args) do
    apply(mod, fun, [conn | args])
  end

  @spec get_conn_fields(Plug.Conn.t(), keyword) :: list
  @doc false
  def get_conn_fields(%Plug.Conn{} = conn, extra_fields \\ []) do
    # We use `Keyword.put` to add items to the list, which prepends items to the list, and so we
    # add items in reverse order of how we want them to appear in the log message.
    extra_fields
    |> maybe_put_headers(conn)
    |> Keyword.put(:status, conn.status)
    |> maybe_put_query_params(conn)
    |> put_params(conn)
    |> maybe_put_phoenix_info(conn)
    |> Keyword.put(:path, conn.request_path)
    |> Keyword.put(:method, conn.method)
    |> maybe_put_host(conn)
    |> Keyword.put(:state, format_state(conn.state))
    |> maybe_remove_excluded_fields()
    |> maybe_rename_fields()
  end

  defp format_state(:set_chunked), do: "chunked"
  defp format_state(_), do: "sent"

  defp maybe_put_host(fields, %Plug.Conn{host: host}) do
    if extra_fields() |> Enum.member?(:host) do
      fields |> Keyword.put(:host, host)
    else
      fields
    end
  end

  defp maybe_put_phoenix_info(fields, %Plug.Conn{
         private: %{phoenix_controller: controller, phoenix_action: action}
       }) do
    fields
    |> Keyword.put(:action, Atom.to_string(action))
    |> Keyword.put(:controller, inspect(controller))
  end

  defp maybe_put_phoenix_info(fields, _), do: fields

  defp put_params(fields, %Plug.Conn{params: %Plug.Conn.Unfetched{}}),
    do: fields |> Keyword.put(:params, "[UNFETCHED]")

  defp put_params(fields, %Plug.Conn{params: params}), do: put_params(fields, params)

  defp put_params(fields, params) do
    params =
      params
      |> filter_values()
      |> format_values()

    fields |> Keyword.put(:params, params)
  end

  defp maybe_put_query_params(fields, conn) do
    if extra_fields() |> Enum.member?(:query_params) do
      fields |> do_put_query_params(conn)
    else
      fields
    end
  end

  defp do_put_query_params(fields, %Plug.Conn{query_params: %Plug.Conn.Unfetched{}}),
    do: fields |> Keyword.put(:query_params, "[UNFETCHED]")

  defp do_put_query_params(fields, %Plug.Conn{query_params: query_params}),
    do: do_put_query_params(fields, query_params)

  defp do_put_query_params(fields, query_params) do
    query_params =
      query_params
      |> filter_values()
      |> format_values()

    fields |> Keyword.put(:query_params, query_params)
  end

  # convenience method to put the params at the end of the given list
  defp append_params(fields, params), do: fields ++ put_params([], params)

  defp maybe_put_headers(fields, conn),
    do: do_maybe_put_headers(fields, conn, Application.get_env(:logster, :headers, []))

  defp do_maybe_put_headers(fields, _conn, []), do: fields

  defp do_maybe_put_headers(fields, conn, loggable_headers) do
    headers =
      conn.req_headers
      |> Enum.filter(fn {k, _} -> Enum.member?(loggable_headers, k) end)
      |> Enum.into(%{}, fn {k, v} -> {k, v} end)

    fields |> Keyword.put(:headers, headers)
  end

  defp maybe_remove_excluded_fields(fields),
    do: fields |> Keyword.drop(Application.get_env(:logster, :excludes, []))

  defp maybe_rename_fields(params, renames \\ Application.get_env(:logster, :renames, []))

  defp maybe_rename_fields(fields, []), do: fields

  defp maybe_rename_fields(fields, renames) do
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

  defp filter_values(
         params,
         filter_config \\ Application.get_env(
           :logster,
           :filter_parameters,
           @default_filter_parameters
         )
       )

  defp filter_values(params, {:discard, discard_params}),
    do: discard_values(params, discard_params)

  defp filter_values(params, {:keep, keep_params}), do: keep_values(params, keep_params)
  defp filter_values(params, filtered_params), do: discard_values(params, filtered_params)

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

  defp keep_values([_ | _] = list, keep_params) do
    Enum.map(list, &keep_values(&1, keep_params))
  end

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

  defp format_duration(duration) do
    microseconds = duration |> System.convert_time_unit(:native, :microsecond)
    microseconds / 1000
  end

  defp extra_fields, do: Application.get_env(:logster, :extra_fields, [])

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
      ) do
    case log_level(metadata[:options][:log], conn) do
      false -> :ok
      level -> log_conn(level, conn, duration)
    end
  end

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
end
