defmodule Uppy.Scheduler do
  @moduledoc """
  ...
  """

  alias Uppy.Config

  @type source :: binary()
  @type queryable :: Ecto.Queryable.t()
  @type source_queryable :: {source(), queryable()}
  @type query :: Ecto.Query.t()

  @type bucket :: binary()
  @type id :: term()
  @type object :: binary()
  @type opts :: keyword()

  @type schedule_at :: DateTime.t()
  @type schedule_in :: non_neg_integer()
  @type schedule :: schedule_at() | schedule_in() | nil

  @callback queue_delete_object_and_upload(
    bucket :: bucket(),
    query :: queryable() | source_queryable() | query(),
    id :: id(),
    opts :: opts()
  ) :: {:ok, term()} | {:error, term()}

  @callback queue_abort_multipart_upload(
    bucket :: bucket(),
    query :: queryable() | source_queryable() | query(),
    id :: id(),
    opts :: opts()
  ) :: {:ok, term()} | {:error, term()}

  @callback queue_abort_upload(
    bucket :: bucket(),
    query :: queryable() | source_queryable() | query(),
    id :: id(),
    opts :: opts()
  ) :: {:ok, term()} | {:error, term()}

  @callback queue_move_upload(
    bucket :: bucket(),
    destination_object :: binary(),
    query :: queryable() | source_queryable() | query(),
    id :: id(),
    pipeline_module :: module() | nil,
    opts :: opts()
  ) :: {:ok, term()} | {:error, term()}

  def queue_delete_object_and_upload(
    bucket,
    query,
    id,
    opts
  ) do
    adapter!(opts).queue_delete_object_and_upload(
      bucket,
      query,
      id,
      opts
    )
  end

  def queue_abort_multipart_upload(
    bucket,
    query,
    id,
    opts
  ) do
    adapter!(opts).queue_abort_multipart_upload(
      bucket,
      query,
      id,
      opts
    )
  end

  def queue_abort_upload(
    bucket,
    query,
    id,
    opts
  ) do
    adapter!(opts).queue_abort_upload(
      bucket,
      query,
      id,
      opts
    )
  end

  def queue_move_upload(
    bucket,
    destination_object,
    query,
    id,
    pipeline_module,
    opts
  ) do
    adapter!(opts).queue_move_upload(
      bucket,
      destination_object,
      query,
      id,
      pipeline_module,
      opts
    )
  end

  defp adapter!(opts) do
    with nil <- opts[:scheduler_adapter],
      nil <- Config.scheduler_adapter() do
      Uppy.Schedulers.ObanScheduler
    end
  end
end
