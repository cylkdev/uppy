defmodule Uppy.Phases.PermanentObjectKeyValidate do
  @moduledoc """
  ...
  """
  alias Uppy.{PermanentObjectKey, Utils}

  @type input :: map()
  @type options :: keyword()

  @type t_res(t) :: {:ok, t} | {:error, term()}

  @behaviour Uppy.Adapter.Phase

  @logger_prefix "Uppy.Phases.PermanentObjectKeyValidate"

  @impl Uppy.Adapter.Phase
  @doc """
  Implementation for `c:Uppy.Adapter.Phase.run/2`
  """
  @spec run(input(), options()) :: t_res(input())
  def run(
        %Uppy.Pipeline.Input{
          schema_data: schema_data
        } = input,
        options
      ) do
    Utils.Logger.debug(@logger_prefix, "RUN BEGIN", binding: binding())

    with {:ok, _} <- PermanentObjectKey.validate(schema_data.key, options) do
      {:ok, input}
    end
  end
end
