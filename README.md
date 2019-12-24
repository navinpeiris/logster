# Logster

[![Build Status](https://travis-ci.org/navinpeiris/logster.svg?branch=master)](https://travis-ci.org/navinpeiris/logster)
[![Hex version](https://img.shields.io/hexpm/v/logster.svg "Hex version")](https://hex.pm/packages/logster)
[![Hex downloads](https://img.shields.io/hexpm/dt/logster.svg "Hex downloads")](https://hex.pm/packages/logster)
[![License](http://img.shields.io/:license-mit-blue.svg)](http://doge.mit-license.org)

An easy to parse, one line logger for Elixir Plug.Conn and Phoenix, inspired by [lograge](https://github.com/roidrage/lograge).

With the default `Plug.Logger`, the log output for a request looks like:
```
[info] GET /articles/some-article
[info] Sent 200 in 21ms
```

With Logster, we've got logging that's much easier to parse and search through, such as:
```
[info] method=GET path=/articles/some-article format=html controller=HelloPhoenix.ArticleController action=show params={"id":"some-article"} status=200 duration=0.402 state=set
```

This becomes handy specially when integrating with log management services such as [Logentries](https://logentries.com/) or [Papertrail](https://papertrailapp.com/).

## Installation

First, add Logster to your `mix.exs` dependencies:

```elixir
def deps do
  [{:logster, "~> 1.0"}]
end
```

Then, update your dependencies:

```
$ mix deps.get
```

## Usage

To use with a Phoenix application, replace `Plug.Logger` in the projects `endpoint.ex` file with `Logster.Plugs.Logger`:

```elixir
# plug Plug.Logger
plug Logster.Plugs.Logger
```

To use it in as a plug, just add `plug Logster.Plugs.Logger` into the relevant module.

### Filtering parameters

By default, Logster filters parameters named `password`, and replaces the content with `[FILTERED]`.

You can update the list of parameters that are filtered by adding the following to your configuration file:

```elixir
config :logster, :filter_parameters, ["password", "secret", "token"]
```

### HTTP headers support

By default, Logster won't parse and log HTTP headers.

But you can update the list of headers that should be parsed and logged. The logged headers will be added under `headers`. Both plain text and JSON formatters are supported.

```elixir
config :logster, :allowed_headers, ["my-header-one", "my-header-two"]
```

### Changing the log level for a specific controller/action

To change the Logster log level for a specific controller and/or action, you use the `Logster.Plugs.ChangeLogLevel` plug.

For example, to change the logging of all requests in a controller to `debug`, add the following to that controller:

```elixir
plug Logster.Plugs.ChangeLogLevel, to: :debug
```

And to change it only for `index` and `show` actions:

```elixir
plug Logster.Plugs.ChangeLogLevel, to: :debug when action in [:index, :show]
```

This is specially useful for cases such as when you want to lower the log level for a healthcheck endpoint that gets hit every few seconds.

### Changing the formatter

Logster allows you to use a different formatter to get your log lines looking just how you want. It comes with two built-in formatters: `Logster.StringFormatter` and `Logster.JSONFormatter`

To use `Logster.JSONFormatter`, supply the `formatter` option when you use the `Logster.Plugs.Logger` plug:

```elixir
plug Logster.Plugs.Logger, formatter: Logster.JSONFormatter
```

That means your log messages will be formatted thusly:
```
{"status":200,"state":"set","path":"hello","params":{},"method":"GET","format":"json","duration":20.647,"controller":"App.HelloController","action":"show"
```
*Caution:* There is no guarantee that what reaches your console will be valid JSON. The Elixir `Logger` module has its own formatting which may be appended to your message. See the [Logger documentation](http://elixir-lang.org/docs/stable/logger/Logger.html) for more information.

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

The easiest way to do this app wide is to introduce a new plug which you can include in your phoenix router pipeline.

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

### Renaming default fields

You can rename the default keys passing a map like `%{key: :new_key}`:

```elixir
plug Logster.Plugs.Logger, renames: %{duration: :response_time, params: :parameters}
```
It will log the following:
```
[info] method=GET path=/articles/some-article format=html controller=HelloPhoenix.ArticleController action=show parameters={"id":"some-article"} status=200 response_time=0.402 state=set
```

### Excluding fields

You can exclude fields with `:excludes`:

```elixir
plug Logster.Plugs.Logger, excludes: [:params, :status, :state]
```
It will log the following:
```
[info] method=GET path=/articles/some-article format=html controller=HelloPhoenix.ArticleController action=show duration=0.402
```

#### Writing your own formatter

To write your own formatter, all that is required is a module which defines a `format/1` function, which accepts a keyword list and returns a string.

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
