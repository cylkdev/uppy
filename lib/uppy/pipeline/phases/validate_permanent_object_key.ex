defmodule Uppy.Pipeline.Phases.ValidatePermanentObjectKey do
  @moduledoc """
  Returns the input if the field `:key` on the `schema_data` struct
  is a permanent object key.
  """

  @behaviour Uppy.Adapter.Pipeline.Phase

  alias Uppy.{Config, PermanentObjectKeys}

  def run(
    %{
      schema_data: schema_data,
      options: runtime_options
    } = input,
    _phase_options
  ) do
    permanent_object_key_adapter = permanent_object_key_adapter!(runtime_options)

    with {:ok, _} <-
      PermanentObjectKeys.validate_path(permanent_object_key_adapter, schema_data.key) do
      {:ok, input}
    end
  end

  defp permanent_object_key_adapter!(options) do
    Keyword.get(options, :permanent_object_key_adapter, Config.permanent_object_key_adapter())
  end
end
