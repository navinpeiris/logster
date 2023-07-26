defmodule Logster.Formatters.JSONTest do
  use ExUnit.Case, async: true

  @formatter Logster.Formatters.JSON

  test "formats message when given keyword list" do
    result =
      [
        one: "two",
        foo: :bar,
        baz: 123_456,
        qux: 123.456789689987,
        xyz: %{
          fi: "fo"
        }
        # zzz: {"one", "two"}
      ]
      |> @formatter.format()
      |> IO.iodata_to_binary()

    assert result ==
             ~s({"foo":"bar","one":"two","baz":123456,"qux":123.456789689987,"xyz":{"fi":"fo"}})
  end

  test "handles fields with a non-json convertible map" do
    result =
      [
        xyz: %{
          fi: {"fo"}
        }
      ]
      |> @formatter.format()
      |> IO.iodata_to_binary()

    assert result == ~s({"msg":"%{xyz: %{fi: {\\"fo\\"}}}"})
  end

  test "formats message when given a string" do
    result =
      "message"
      |> @formatter.format()
      |> IO.iodata_to_binary()

    assert result == ~s({"msg":"message"})
  end

  test "formats message when given a list" do
    result =
      ["one", "two", "three"]
      |> @formatter.format()
      |> IO.iodata_to_binary()

    assert result == ~s({"msg":["one","two","three"]})
  end

  test "formats message when given other" do
    result =
      123
      |> @formatter.format()
      |> IO.iodata_to_binary()

    assert result == ~s({"msg":"123"})
  end

  test "can handle maps" do
    result =
      %{one: "two", foo: "bar"}
      |> @formatter.format()
      |> IO.iodata_to_binary()

    assert result == ~s({"foo":"bar","one":"two"})
  end

  test "can handle empty lists" do
    result =
      []
      |> @formatter.format()
      |> IO.iodata_to_binary()

    assert result == ""
  end

  test "can handle tuples" do
    result =
      {"one", "two", "three"}
      |> @formatter.format()
      |> IO.iodata_to_binary()

    assert result == ~s({"msg":"{\\"one\\", \\"two\\", \\"three\\"}"})
  end
end
