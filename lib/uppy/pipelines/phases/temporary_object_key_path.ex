defmodule Uppy.Pipelines.Phases.TemporaryObjectKeyPath do
  @moduledoc """
  Returns the input if the field `:key` on the `schema_data` struct
  is a temporary object key.
  """

  @behaviour Uppy.Adapter.Pipeline.Phase

  @logger_prefix "Uppy.Pipeline.Phases.TemporaryObjectKeyPath"

  alias Uppy.{Config, TemporaryObjectKeys, Utils}

  def run(
        %{
          schema_data: schema_data,
          options: runtime_options
        } = input,
        _phase_options
      ) do
    temporary_object_key_adapter = temporary_object_key_adapter!(runtime_options)

    key = schema_data.key

    Utils.Logger.debug(
      @logger_prefix,
      """
      Checking if schema data key is a temporary object key.

      key: #{inspect(key)}
      temporary_object_key_adapter: #{inspect(temporary_object_key_adapter)}
      """
    )

    case TemporaryObjectKeys.validate_path(temporary_object_key_adapter, schema_data.key) do
      {:ok, res} ->
        Utils.Logger.debug(
          @logger_prefix,
          "detected key #{inspect(key)} as a temporary object key with response: #{inspect(res)}"
        )

        {:ok, input}

      {:error, _} = error ->
        Utils.Logger.debug(
          @logger_prefix,
          "failed to validate key #{inspect(key)} as a temporary object key with reason #{inspect(error, pretty: true)}."
        )

        error
    end
  end

  defp temporary_object_key_adapter!(options) do
    Keyword.get(options, :temporary_object_key_adapter, Config.temporary_object_key_adapter())
  end
end
