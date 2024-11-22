defmodule Uppy.Storages.S3.Parser do
  @moduledoc """
  ...
  """

  @doc """
  Parses datetime in http headers that follow the Internet Message Format RFC7231.

  ### Examples

      iex> Uppy.Storages.S3.Parser.date_time_from_rfc7231!("Sat, 16 Sep 2023 04:13:38 GMT")
      ~U[2023-09-16 04:13:38Z]
  """
  @spec date_time_from_rfc7231!(binary(), binary(), atom()) :: DateTime.t()
  def date_time_from_rfc7231!(
        string,
        to_timezone \\ "Etc/UTC",
        time_zone_database \\ Tzdata.TimeZoneDatabase
      ) do
    [day, month, year, time, timezone] = split_rfc7231!(string)

    [hour, minute, second] = time |> String.split(":") |> Enum.map(&String.to_integer/1)

    year = String.to_integer(year)
    month = month |> String.downcase() |> month_to_integer()
    day = String.to_integer(day)

    date = Date.new!(year, month, day)
    time = Time.new!(hour, minute, second)

    date
    |> DateTime.new!(time, timezone, time_zone_database)
    |> DateTime.shift_zone!(to_timezone)
  end

  defp split_rfc7231!(string) do
    result =
      string
      |> String.split(",")
      |> List.last()
      |> String.split(" ", trim: true)

    case result do
      [day, month, year, time, timezone] -> [day, month, year, time, timezone]
      _ -> raise "Expected a valid rfc7231 string, got: #{inspect(string)}"
    end
  end

  defp month_to_integer("jan" <> _), do: 1
  defp month_to_integer("feb" <> _), do: 2
  defp month_to_integer("mar" <> _), do: 3
  defp month_to_integer("apr" <> _), do: 4
  defp month_to_integer("may"), do: 5
  defp month_to_integer("jun" <> _), do: 6
  defp month_to_integer("jul" <> _), do: 7
  defp month_to_integer("aug" <> _), do: 8
  defp month_to_integer("sep" <> _), do: 9
  defp month_to_integer("oct" <> _), do: 10
  defp month_to_integer("nov" <> _), do: 11
  defp month_to_integer("dec" <> _), do: 12
end
