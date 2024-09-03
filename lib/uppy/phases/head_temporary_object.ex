defmodule Uppy.Phases.HeadTemporaryObject do
  @moduledoc """
  ...
  """
  alias Uppy.{Storage, Utils}

  @type input :: map()
  @type schema :: Ecto.Queryable.t()
  @type schema_data :: Ecto.Schema.t()
  @type params :: map()
  @type options :: keyword()

  @type t_res(t) :: {:ok, t} | {:error, term()}

  @behaviour Uppy.Adapter.Phase

  @logger_prefix "Uppy.Phases.HeadTemporaryObject"

  def run(
    %Uppy.Pipeline.Input{
      bucket: bucket,
      schema_data: schema_data,
      context: context
    } = input,
    options
  ) do
    Utils.Logger.debug(@logger_prefix, "run BEGIN")

    with {:ok, metadata} <- Storage.head_object(bucket, schema_data.key, options) do
      {:ok, %{input | context: Map.put(context, :metadata, metadata)}}
    end
  end
end
