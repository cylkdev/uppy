defmodule Uppy.Scheduler do
  @moduledoc """
  ...
  """

  alias Uppy.Config

  @type id :: non_neg_integer() | binary()
  @type bucket :: binary()
  @type resource :: binary()
  @type queryable :: Ecto.Queryable.t()
  @type key :: binary()
  @type opts :: keyword()

  @type schedule_at :: DateTime.t()
  @type schedule_in :: non_neg_integer()
  @type schedule :: schedule_at() | schedule_in() | nil

  @type t_res(t) :: {:ok, t} | {:error, term()}

  @default_adapter Uppy.Schedulers.Oban

  @doc """
  Enqueues a job to delete an object from storage if the database record does not exist.
  """
  @callback queue_garbage_collect_object(
              bucket :: bucket(),
              schema :: queryable(),
              key :: key(),
              schedule :: schedule(),
              opts :: opts()
            ) :: t_res(term())

  @doc """
  Enqueues a job to abort a multipart upload and delete the database record if the key is in a temporary path.
  """
  @callback queue_abort_multipart_upload(
              bucket :: bucket(),
              schema :: queryable(),
              id :: id(),
              schedule :: schedule(),
              opts :: opts()
            ) :: t_res(term())

  @doc """
  Enqueues a job to delete a non-multipart upload database record if the key is in a temporary path.
  """
  @callback queue_abort_upload(
              bucket :: bucket(),
              schema :: queryable(),
              id :: id(),
              schedule :: schedule(),
              opts :: opts()
            ) :: t_res(term())

  @doc """
  Enqueues a job to run a pipeline.
  """
  @callback queue_process_upload(
              pipeline_module :: module(),
              bucket :: bucket(),
              resource :: resource(),
              schema :: queryable(),
              id :: id(),
              schedule :: schedule(),
              opts :: opts()
            ) :: t_res(term())

  def queue_garbage_collect_object(
    bucket,
    schema,
    key,
    schedule,
    opts
  ) do
    bucket
    |> adapter!(opts).queue_garbage_collect_object(
      schema,
      key,
      schedule,
      opts
    )
    |> handle_response()
  end

  def queue_abort_multipart_upload(
    bucket,
    schema,
    id,
    schedule,
    opts
  ) do
    bucket
    |> adapter!(opts).queue_abort_multipart_upload(
      schema,
      id,
      schedule,
      opts
    )
    |> handle_response()
  end

  def queue_abort_upload(
    bucket,
    schema,
    id,
    schedule,
    opts
  ) do
    bucket
    |> adapter!(opts).queue_abort_upload(
      schema,
      id,
      schedule,
      opts
    )
    |> handle_response()
  end

  def queue_process_upload(
    pipeline_module,
    bucket,
    resource,
    schema,
    id,
    schedule,
    opts
  ) do
    pipeline_module
    |> adapter!(opts).queue_process_upload(
      bucket,
      resource,
      schema,
      id,
      schedule,
      opts
    )
    |> handle_response()
  end

  defp adapter!(opts) do
    with nil <- opts[:scheduler_adapter],
      nil <- Config.scheduler_adapter() do
      @default_adapter
    end
  end

  defp handle_response({:ok, _} = ok), do: ok
  defp handle_response({:error, _} = error), do: error
  defp handle_response(term) do
    raise """
    Expected one of:

    `{:ok, term()}`
    `{:error, term()}`

    got:
    #{inspect(term, pretty: true)}
    """
  end
end
