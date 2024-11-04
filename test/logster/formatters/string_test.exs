defmodule Logster.Formatters.StringTest do
  use ExUnit.Case, async: true

  @formatter Logster.Formatters.String

  test "formats message when given keyword list" do
    result =
      [
        one: "two",
        foo: :bar,
        baz: 123_456,
        qux: 123.456789689987,
        xyz: %{
          fi: "fo"
        },
        zzz: {"one", "two"}
      ]
      |> @formatter.format()
      |> IO.iodata_to_binary()

    assert result == ~s(one=two foo=bar baz=123456 qux=123.457 xyz={"fi":"fo"} zzz={"one", "two"})
  end

  test "can override the number of decimals for a string" do
    old = Application.get_env(:logster, @formatter) || []

    on_exit(fn ->
      Application.put_env(:logster, @formatter, old)
    end)

    log = [bar: 123.4567]

    Application.put_env(:logster, @formatter, Keyword.put(old, :decimals, 1))

    result = log |> @formatter.format() |> IO.iodata_to_binary()
    assert result == ~s(bar=123.5)

    Application.put_env(:logster, @formatter, Keyword.put(old, :decimals, nil))

    result = log |> @formatter.format() |> IO.iodata_to_binary()
    assert result == ~s(bar=123.4567)
  end

  test "formats field with a non-json convertible map" do
    result =
      [
        xyz: %{
          fi: {"fo"}
        }
      ]
      |> @formatter.format()
      |> IO.iodata_to_binary()

    assert result == ~s(xyz=%{fi: {"fo"}})
  end

  test "formats message when given a string" do
    result =
      "message"
      |> @formatter.format()
      |> IO.iodata_to_binary()

    assert result == "message"
  end

  test "formats message when given a list" do
    result =
      ["one", "two", "three"]
      |> @formatter.format()
      |> IO.iodata_to_binary()

    assert result == "one two three"
  end

  test "formats message when given other" do
    result =
      123
      |> @formatter.format()
      |> IO.iodata_to_binary()

    assert result == "123"
  end
end
