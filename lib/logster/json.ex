defmodule Logster.JSON do
  @moduledoc false
  # Delegates to JSON in Elixir v1.18+ or Jason for earlier versions
  cond do
    Code.ensure_loaded?(JSON) ->
      defdelegate encode_to_iodata!(data), to: JSON

    Code.ensure_loaded?(Jason) ->
      defdelegate encode_to_iodata!(data), to: Jason

    true ->
      message = "Missing a compatible JSON library, add `:jason` to your deps."
      IO.warn(message, Macro.Env.stacktrace(__ENV__))
  end
end
