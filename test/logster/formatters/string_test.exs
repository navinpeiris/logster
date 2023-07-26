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
