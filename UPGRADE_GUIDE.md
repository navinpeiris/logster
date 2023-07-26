# Upgrade Guide

## v1.x to v2.0.0-rc.1

### Phoenix users:

1. Attach the new logger through telemetry events in your project's `application.ex` file:

```elixir
# lib/pixie/application.ex
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

2. Locate the line installing `Logster.Plugs.Logger` in your `endpoint.ex` file.

```elixir
plug Logster.Plugs.Logger,
  # Configuration options such as those below might not be present
  formatter: Logster.Plugs.JSONFormatter,
  allowed_headers: ["content-type"],
  excludes: [:params]
```

3. If configuration options were passed to `Logster.Plugs.Logger`, move them to `config.exs`:

```elixir
config :logster,
  formatter: :json,
  headers: ["content-type"],
  excludes: [:params]
```

NOTE: `allowed_headers` option has been renamed to `headers`

4. Remove the line installing `Logster.Plugs.Logger` from your `endpoint.ex` file.

5. Locate any calls to `Logster.Plugs.ChangeLogLevel` and rename it to `Logster.ChangeLogLevel`

6. Add the following to `config.exs` to disable the default Phoenix logger:

```elixir
config :phoenix, :logger, false
```

### Plug users:

1. Move any configuration options passed to `Logster.Plugs.Logger` to `config.exs` (See above section for more information).

1. Locate any calls to `Logster.Plugs.Logger` and rename it to `Logster.Plug`

1. Locate any calls to `Logster.Plugs.ChangeLogLevel` and rename it to `Logster.ChangeLogLevel`
