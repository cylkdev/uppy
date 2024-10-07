defmodule Uppy.Phases.ValidateObjectTemporaryPath do
  @moduledoc """
  ...
  """
  alias Uppy.{PathBuilder, Utils}

  @behaviour Uppy.Phase

  @logger_prefix "Uppy.Phases.ValidateObjectTemporaryPath"

  @doc """
  Implementation for `c:Uppy.Phase.run/2`
  """
  @impl true
  def run(%Uppy.Resolution{value: schema_data} = resolution, opts) do
    Utils.Logger.debug(@logger_prefix, "run BEGIN")

    with :ok <- PathBuilder.validate_temporary_path(schema_data.key, opts) do
      {:ok, resolution}
    end
  end
end
