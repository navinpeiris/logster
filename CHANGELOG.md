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
