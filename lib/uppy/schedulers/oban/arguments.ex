defmodule Uppy.Schedulers.Oban.Arguments do
  @moduledoc false

  alias Uppy.Utils

  def convert_schema_to_arguments({schema, source}) do
    %{
      schema: Utils.module_to_string(schema),
      source: source
    }
  end

  def convert_schema_to_arguments(schema) do
    %{
      schema: Utils.module_to_string(schema)
    }
  end
end
