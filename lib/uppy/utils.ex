defmodule Uppy.Utils do
  @moduledoc false

  @web_safe_filename_regex ~r|^[[:alnum:]\!\-\_\.\*\'\(\)]+$|u

  @doc """
  Returns a regex that validates a filename is compliant with DNS,
  web-safe characters, XML parsers, and other APIs.

  Read more: https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-keys.html
  """
  @spec web_safe_filename_regex :: Regex.t()
  def web_safe_filename_regex, do: @web_safe_filename_regex

  @spec ensure_all_loaded?(list()) :: boolean()
  def ensure_all_loaded?(modules) do
    Enum.all?(modules, &Code.ensure_loaded?/1)
  end

  @spec to_existing_module!(String.t()) :: atom()
  def to_existing_module!(string) do
    String.to_existing_atom("Elixir.#{string}")
  end

  @spec module_to_string(module()) :: String.t()
  def module_to_string(module), do: String.replace("#{module}", "Elixir.", "")

  @spec generate_unique_identifier(non_neg_integer()) :: binary()
  def generate_unique_identifier(size) do
    size
    |> :crypto.strong_rand_bytes()
    |> url_safe_encode64()
  end

  @spec url_safe_encode64(binary()) :: binary()
  def url_safe_encode64(plaintext) do
    plaintext
    |> Base.encode64(padding: false)
    |> String.replace(["+", "/"], "")
  end

  @doc """
  Parses datetime in http headers that follow the Internet Message Format RFC7231.
  """
  @spec date_time_from_rfc7231!(String.t()) :: DateTime.t()
  def date_time_from_rfc7231!(string) do
    [day, month, year, time, timezone] =
      string
      |> String.split(",")
      |> List.last()
      |> String.split(" ", trim: true)

    [hour, minute, second] = String.split(time, ":")

    year = String.to_integer(year)
    month = month_to_integer(month)
    day = String.to_integer(day)

    hour = String.to_integer(hour)
    minute = String.to_integer(minute)
    second = String.to_integer(second)

    date = Date.new!(year, month, day)
    time = Time.new!(hour, minute, second)

    date
    |> DateTime.new!(time, timezone)
    |> DateTime.shift_zone!("Etc/UTC")
  end

  defp month_to_integer("Jan" <> _), do: 1
  defp month_to_integer("Feb" <> _), do: 2
  defp month_to_integer("Mar" <> _), do: 3
  defp month_to_integer("Apr" <> _), do: 4
  defp month_to_integer("May"), do: 5
  defp month_to_integer("Jun" <> _), do: 6
  defp month_to_integer("Jul" <> _), do: 7
  defp month_to_integer("Aug" <> _), do: 8
  defp month_to_integer("Sep" <> _), do: 9
  defp month_to_integer("Oct" <> _), do: 10
  defp month_to_integer("Nov" <> _), do: 11
  defp month_to_integer("Dec" <> _), do: 12
end
