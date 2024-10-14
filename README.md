# Logster

[![CI](https://github.com/navinpeiris/logster/actions/workflows/ci.yml/badge.svg)](https://github.com/navinpeiris/logster/actions/workflows/ci.yml)
[![Hex version](https://img.shields.io/hexpm/v/logster.svg "Hex version")](https://hex.pm/packages/logster)
[![Hex downloads](https://img.shields.io/hexpm/dt/logster.svg "Hex downloads")](https://hex.pm/packages/logster)
[![License](http://img.shields.io/:license-mit-blue.svg)](http://doge.mit-license.org)

> **Note**\
> This is the documentation for v2 of Logster. If you're looking for v1, see the [v1 branch](https://github.com/navinpeiris/logster/tree/v1.x).

<!-- MDOC -->

An easy-to-parse, single-line logger for Elixir Phoenix and Plug.Conn, inspired by [lograge](https://github.com/roidrage/lograge). Supports logfmt, JSON and custom output formatting.

By default, Phoenix log output for a request looks similar to the following:

```
[info] GET /articles/some-article
[debug] Processing with HelloPhoenix.ArticleController.show/2
  Parameters: %{"id" => "some-article"}
  Pipelines: [:browser]
[info] Sent 200 in 21ms
```

This can be handy for development, but cumbersome for production. The log output is spread across multiple lines, making it difficult to parse and search.

Logster aims to solve this problem by logging the request in a single line:

```
[info] state=sent method=GET path=/articles/some-article format=html controller=HelloPhoenix.ArticleController action=show params={"id":"some-article"} status=200 duration=0.402
```

This is especially handy when integrating with log management services such as [Logentries](https://logentries.com/) or [Papertrail](https://papertrailapp.com/).

Alternatively, Logster can also output JSON formatted logs (see configuration section below):

```
[info] {"state":"sent","method":"GET","path":"/articles/some-article","format":"html","controller":"HelloPhoenix.ArticleController","action":"show","params":{"id":"some-article"},"status":200,"duration":0.402}
```

## Installation

Add `:logster` to the list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:logster, "~> 2.0.0-rc.1"}]
end
```

## Upgrading

See [Upgrade Guide](UPGRADE_GUIDE.md) for more information.

## Usage

### Using with Phoenix

Attach the Logster Phoenix logger in the `start` function in your project's `application.ex` file:

```elixir
# lib/my_app/application.ex
def start(_type, _args) do
  children = [
    # ...
  ]

  #
  # Add the line below:
  #
  :ok = Logster.attach_phoenix_logger()

  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

Next, disable the default Phoenix logger by adding the following line to your `config.exs` file:

```elixir
config :phoenix, :logger, false
```

### Using with Plug

Add `Logster.Plug` to your plug pipeline, or in the relevant module:

```elixir
plug Logster.Plug
```

### Using standalone logger

Logster provides `debug`, `info`, `warning`, `error` etc convenience functions that mimic those provided by the elixir logger, which outputs messages in your chosen log format.

For example:

```elixir
Logster.info(service: :payments, event: :received, amount: 1000, customer: 123)
```

will output the following to the logs:

```
[info] service=payments event=received amount=1000 customer=123
```

You can also provide a function to be called lazily, which will only be called if the log level is enabled:

```elixir
Logster.debug(fn ->
  # some potentially expensive operation
  # won't be called if the log level is not enabled
  customer = get_customer_id()

  [service: :payments, event: :received, amount: 1000, customer: customer]
end)
```

## Configuration

The following configuration options can be set through your `config.exs` file

### Formatter

#### JSON formatter

```elixir
config :logster, formatter: :json
```

_Caution:_ There is no guarantee that what reaches your console will be valid JSON. The Elixir `Logger` module has its own formatting which may be appended to your message. See the [Logger documentation](http://elixir-lang.org/docs/stable/logger/Logger.html) for more information.

#### Custom formatter

Provide a function that takes one argument, the parameters as input, and returns formatted output

```elixir
config :logster, formatter: &MyCustomFormatter.format/1
```

### Filtering parameters

By default, Logster filters parameters named `password`.

To change the filtered parameters:

```elixir
config :logster, filter_parameters: ["password", "secret", "token"]
```

### Logging HTTP request headers

By default, Logster won't log any request headers. To log specific headers, you can use the `:headers` option:

```elixir
config :logster, headers: ["my-header-one", "my-header-two"]
```

### Changing the log level for a specific controller/action

#### Through Logster.ChangeLogLevel plug

To change the Logster log level for a specific controller and/or action, you use the `Logster.ChangeLogLevel` plug.

For example, to change the logging of all requests in a controller to `debug`, add the following to that controller:

```elixir
plug Logster.ChangeLogLevel, to: :debug
```

And to change it only for `index` and `show` actions:

```elixir
plug Logster.ChangeLogLevel, [to: :debug] when action in [:index, :show]
```

This is specially useful for cases such as when you want to lower the log level for a healthcheck endpoint that gets hit every few seconds.

#### Through endpoint configuration

You can set the `Plug.Telemetry` `:log` option to a tuple, `{Mod, Fun, Args}`. `The Plug.Conn.t()` for the request will be prepended to the provided list of arguments.

When invoked, your function must return a `Logger.level()` or `false` to disable logging for the request.

```elixir
# lib/my_app_web/endpoint.ex
plug Plug.Telemetry,
  event_prefix: [:phoenix, :endpoint],
  log: {__MODULE__, :log_level, []}

# Disables logging for routes like /status/*
def log_level(%{status: status}) when status >= 500, do: :error
def log_level(%{status: status}) when status >= 400, do: :warning
def log_level(%{path_info: ["status" | _]}), do: false
def log_level(_), do: :info
```

### Enabling extra fields

One or more of the following fields can be optionally enabled through the `extra_fields` configuration option:

- host
- query_params

Example:

```elixir
config :logster, extra_fields: [:host, :query_params]
```

### Excluding fields

You can exclude fields with `:excludes`:

```elixir
config :logster, excludes: [:params, :status, :state]
```

Example output:

```
[info] method=GET path=/articles/some-article format=html controller=HelloPhoenix.ArticleController action=show duration=0.402
```

### Renaming default fields

You can rename the default keys passing a map like `%{key: :new_key}`:

```elixir
config :logster, renames: [duration: :response_time, params: :parameters]
```

Example output:

```
[info] method=GET path=/articles/some-article format=html controller=HelloPhoenix.ArticleController action=show parameters={"id":"some-article"} status=200 response_time=0.402 state=set
```

### Metadata

Custom metadata can be added to logs using `Logger.metadata` and configuring your logger backend:

```elixir
# add metadata for all future logs from this process
Logger.metadata(%{user_id: "123", foo: "bar"})

# example for configuring console backend to include metadata in logs.
# see https://hexdocs.pm/logger/Logger.html#module-console-backend documentation for more
# config.exs
config :logger, :console, metadata: [:user_id, :foo]
```

The easiest way to do this app wide is to introduce a new plug which you can include in your Phoenix router pipeline.

For example:

```elixir
defmodule HelloPhoenix.SetLoggerMetadata do
  def init(opts), do: opts

  def call(conn, _opts) do
    Logger.metadata user_id: get_user_id(conn),
                    remote_ip: format_ip(conn)
    conn
  end

  defp format_ip(%{remote_ip: remote_ip}) when remote_ip != nil, do: :inet_parse.ntoa(remote_ip)
  defp format_ip(_), do: nil

  defp get_user_id(%{assigns: %{current_user: %{id: id}}}), do: id
  defp get_user_id(_), do: nil
end
```

And then add this plug to the relevant pipelines in the router:

```elixir
pipeline :browser do
  plug :fetch_session
  plug :fetch_flash
  plug :put_secure_browser_headers
  # ...
  plug HelloPhoenix.SetLoggerMetadata
  # ...
end
```

<!-- MDOC -->

## Development

Use the following mix task before pushing commits to run the same checks that are run in CI:

```
mix ci
```

## License

The MIT License

Copyright (c) 2016-present Navin Peiris

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
