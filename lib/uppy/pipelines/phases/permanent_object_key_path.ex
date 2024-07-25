defmodule Uppy.Pipelines.Phases.PermanentObjectKeyPath do
  @moduledoc """
  Returns the input if the field `:key` on the `schema_data` struct
  is a permanent object key.
  """

  @behaviour Uppy.Adapter.Pipeline.Phase

  @logger_prefix "Uppy.Pipeline.Phases.PermanentObjectKeyPath"

  alias Uppy.{Config, PermanentObjectKeys, Utils}

  def run(
        %{
          schema_data: schema_data,
          options: runtime_options
        } = input,
        _phase_options
      ) do
    permanent_object_key_adapter = permanent_object_key_adapter!(runtime_options)

    key = schema_data.key

    Utils.Logger.debug(
      @logger_prefix,
      """
      Checking if schema data key is a permanent object key.

      key: #{inspect(key)}
      permanent_object_key_adapter: #{inspect(permanent_object_key_adapter)}
      """
    )

    case PermanentObjectKeys.validate(permanent_object_key_adapter, schema_data.key) do
      {:ok, res} ->
        Utils.Logger.debug(
          @logger_prefix,
          "detected key #{inspect(key)} as a permanent object key with response: #{inspect(res)}"
        )

        {:ok, input}

      {:error, _} = error ->
        Utils.Logger.debug(
          @logger_prefix,
          "failed to validate key #{inspect(key)} as a permanent object key with reason #{inspect(error, pretty: true)}."
        )

        error
    end
  end

  defp permanent_object_key_adapter!(options) do
    Keyword.get(options, :permanent_object_key_adapter, Config.permanent_object_key_adapter())
  end
end
