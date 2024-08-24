defmodule Uppy.Phases.TemporaryObjectKeyValidate do
  @moduledoc """
  ...
  """
  alias Uppy.PathBuilder

  @type input :: map()
  @type options :: keyword()

  @type t_res(t) :: {:ok, t} | {:error, term()}

  @behaviour Uppy.Adapter.Phase

  @doc """
  Implementation for `c:Uppy.Adapter.Phase.run/2`
  """
  @impl true
  @spec run(input(), options()) :: t_res(input())
  def run(
    %Uppy.Pipeline.Input{
      schema_data: schema_data
    } = input,
    options
  ) do
    with :ok <- PathBuilder.validate_temporary_path(schema_data.key, options) do
      {:ok, input}
    end
  end
end
