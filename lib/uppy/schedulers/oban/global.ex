defmodule Uppy.Schedulers.Oban.Global do
  @moduledoc false

  @default_name Uppy.Oban

  def convert_schema_to_arguments({schema, source}) do
    %{
      schema: Uppy.Utils.module_to_string(schema),
      source: source
    }
  end

  def convert_schema_to_arguments(schema) do
    %{
      schema: Uppy.Utils.module_to_string(schema)
    }
  end

  def insert(changeset, options) do
    options
    |> oban_name!()
    |> Oban.insert(changeset, options)
  end

  defp oban_name!(options), do: options[:oban][:name] || @default_name
end
