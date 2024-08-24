defmodule Uppy.Adapter.Scheduler do
  @moduledoc """
  An adapter for scheduling chron jobs.
  """

  @type id :: non_neg_integer() | binary()
  @type bucket :: binary()
  @type resource :: binary()
  @type queryable :: Ecto.Queryable.t()
  @type key :: binary()
  @type options :: keyword()

  @type schedule_at :: DateTime.t()
  @type schedule_in :: non_neg_integer()

  @type t_res(t) :: {:ok, t} | {:error, term()}

  @doc """
  Enqueues a job to delete an object from storage if the database record does not exist.
  """
  @callback queue_delete_object_if_upload_not_found(
              bucket :: bucket(),
              schema :: queryable(),
              key :: key(),
              schedule_at_or_schedule_in :: schedule_at() | schedule_in(),
              options :: options()
            ) :: t_res(term())

  @doc """
  Enqueues a job to abort a multipart upload and delete the database record if the key is in a temporary path.
  """
  @callback queue_abort_multipart_upload(
              bucket :: bucket(),
              schema :: queryable(),
              id :: id(),
              schedule_at_or_schedule_in :: schedule_at() | schedule_in(),
              options :: options()
            ) :: t_res(term())

  @doc """
  Enqueues a job to delete a non-multipart upload database record if the key is in a temporary path.
  """
  @callback queue_abort_upload(
              bucket :: bucket(),
              schema :: queryable(),
              id :: id(),
              schedule_at_or_schedule_in :: schedule_at() | schedule_in(),
              options :: options()
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
              nil_or_schedule_at_or_schedule_in :: schedule_at() | schedule_in() | nil,
              options :: options()
            ) :: t_res(term())
end
