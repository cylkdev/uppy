defmodule Uppy.Schedulers.Oban.Global do
  @moduledoc false

  @default_name Uppy.Oban

  def insert(changeset, options) do
    options
    |> oban_name!()
    |> Oban.insert(changeset, options)
  end

  defp oban_name!(options), do: options[:oban][:name] || @default_name
end
