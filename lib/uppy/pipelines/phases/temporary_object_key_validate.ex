defmodule Uppy.Pipelines.Phases.TemporaryObjectKeyValidate do
  @moduledoc """
  Validates the `key` on the `schema_data` is a temporary object key.
  """
  alias Uppy.{TemporaryObjectKeys, Utils}

  @type input :: map()
  @type options :: keyword()

  @type t_res(t) :: {:ok, t} | {:error, term()}

  @behaviour Uppy.Adapter.Pipeline.Phase

  @logger_prefix "Uppy.Pipelines.Phases.TemporaryObjectKeyValidate"

  @impl Uppy.Adapter.Pipeline.Phase
  @doc """
  Implementation for `c:Uppy.Adapter.Pipeline.Phase.run/2`
  """
  @spec run(input(), options()) :: t_res(input())
  def run(
        %Uppy.Pipelines.Input{
          value: schema_data,
          options: runtime_options
        } = input,
        phase_options
      ) do
    Utils.Logger.debug(@logger_prefix, "run key=#{inspect(schema_data.key)}")

    options = Keyword.merge(phase_options, runtime_options)

    case TemporaryObjectKeys.validate(schema_data.key, options) do
      {:ok, _} -> {:ok, input}
      {:error, _} = error -> error
    end
  end
end
