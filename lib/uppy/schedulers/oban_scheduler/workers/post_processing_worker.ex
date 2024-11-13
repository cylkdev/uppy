defmodule Uppy.Schedulers.ObanScheduler.Workers.PostProcessingWorker do
  @max_attempts 10

  @moduledoc """
  Moves existing objects to pre-set destinations.
  """
  use Oban.Worker,
    queue: :post_processing,
    max_attempts: @max_attempts,
    unique: [
      period: 300,
      states: [:available, :scheduled, :executing]
    ]

  alias Uppy.{
    Schedulers.ObanScheduler.Action,
    Schedulers.ObanScheduler.EventName,
    Schedulers.ObanScheduler.WorkerAPI
  }

  @event_move_upload EventName.move_upload()

  @config Application.compile_env(Uppy.Config.app(), __MODULE__, [])

  @doc """
  ...

  ### EventNames

    * `#{@event_move_upload}`
  """
  @spec perform(Oban.Job.t()) :: {:ok, term()} | {:error, term()}
  def perform(%Oban.Job{
        attempt: @max_attempts,
        args: args
      }) do
    Action.insert(__MODULE__, args, @config[:options] || [])
  end

  def perform(%Oban.Job{
        args:
          %{
            "event" => @event_move_upload,
            "bucket" => bucket,
            "destination" => destination_object,
            "pipeline" => pipeline,
            "id" => id
          } = args
      }) do
    WorkerAPI.move_upload(
      bucket,
      destination_object,
      WorkerAPI.query_from_arguments(args),
      String.to_integer(id),
      WorkerAPI.string_to_module(pipeline),
      @config[:move_upload][:options] || []
    )
  end
end
