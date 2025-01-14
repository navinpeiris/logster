# 2.0.0-rc.4

- Rename `Logster.Formatters.String` to `Logster.Formatters.Logfmt`.
- Change `formatter: :json` option to `formatter: :logfmt`.

# 2.0.0-rc.3

- `extra_fields` configuration to optionally enable `host` and `query_params` params being logged.

# 2.0.0-rc.1

- Introduce `Logster.attach_phoenix_logger/1`, which attaches a phoenix telemetry event listener for logging. This is the recommended way to use Logster with Phoenix.
- Introduce `Logster.info/3`, `Logster.debug/3`, `Logster.warning/3`, `Logster.error/3` etc. These functions mimic those provided by the elixir logger, which outputs messages in your chosen log format.
- Logs socket events.
- Move all configuration options to be set through `config.exs`.
- Rename `Logster.Plugs.Logger` to `Logster.Plug`.
- Rename `Logster.Plugs.ChangeLogLevel` to `Logster.ChangeLogLevel`.
- Rename `Logster.StringFormatter` to `Logster.Formatters.String`.
- Rename `Logster.JSONFormatter` to `Logster.Formatters.JSON`.
- Specify formatter using atoms instead of module:
  - `formatter: :json`
  - `formatter: :string`
- Request state output in logs changed:
  - `state=set` => `state=sent`
  - `state=set_chunked` => `state=chunked`
- Config option `allowed_headers` changed to `headers`.
- Better `mix docs` output.

# 1.1.0

- By default logs responses with 5xx status code with error level and 4xx responses with warning level.

# 1.0.2

- [#23](https://github.com/navinpeiris/logster/pull/23) No longer raises an error if a map can not be encoded in JSON. Thanks to @paulanthonywilson

# 1.0.1

- [#22](https://github.com/navinpeiris/logster/pull/22) Print inspect output for unexpected param values. Thanks to @rubysolo

# 1.0.0

- [#18](https://github.com/navinpeiris/logster/pull/18) Remove duplication of metadata in logs. Thanks to @novaugust

### Breaking Changes

- Any metadata that needs to be logged needs to now be setup in the `Logger` backend configuration. This is so that metadata configuration is centralised and so that there is no duplication of metadata in the logged output. See [Issue#17](https://github.com/navinpeiris/logster/issues/17) for more details.

# 0.10.0

- [#16](https://github.com/navinpeiris/logster/pull/16) Support for when struct params, providing compatibility with [Open API Spex](https://github.com/open-api-spex/open_api_spex). Thanks to @juantascon

# 0.9.0

- [#15](https://github.com/navinpeiris/logster/pull/15) Adds `:excludes` option. Thanks to @ericmj
- Uses `Jason` instead of `Poison` internally for formatting

# 0.8.0

- Handles case when params are not fetched, such as when logging static assets

# 0.7.0

- [#13](https://github.com/navinpeiris/logster/pull/13) Ability to rename the fields being logged. Thanks to @pbrudnick

# 0.6.0

- Fixes issue where all strings were getting url encoded in log output

# 0.5.0

- [#10](https://github.com/navinpeiris/logster/issues/10) Fixes issue where an exception was thrown when params contains `%` . Thanks to @tsubery

# 0.4.0

- Add HTTP header logging. Thanks to @zepplock

# 0.3.0

- Add custom metadata to the log. Thanks to @tanguyantoine

# 0.2.0

- Introducing custom formatters with String and JSON formatters built in. Thanks to @mootpointer

# 0.1.0

Initial release
