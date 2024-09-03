defmodule Uppy.Phases.ValidateObjectPermanentPath do
  @moduledoc """
  ...
  """
  alias Uppy.{PathBuilder, Utils}

  @type input :: map()
  @type options :: keyword()

  @type t_res(t) :: {:ok, t} | {:error, term()}

  @behaviour Uppy.Adapter.Phase

  @logger_prefix "Uppy.Phases.ValidateObjectPermanentPath"

  @doc """
  Implementation for `c:Uppy.Adapter.Phase.run/2`
  """
  @impl true
  @spec run(input(), options()) :: t_res(input())
  def run(%Uppy.Pipeline.Input{schema_data: schema_data} = input, options) do
    Utils.Logger.debug(@logger_prefix, "run BEGIN")

    with :ok <- PathBuilder.validate_permanent_path(schema_data.key, options) do
      {:ok, input}
    end
  end
end
