defmodule Uppy.Schedulers.ObanScheduler.Config do
  @moduledoc """
  ...
  """

  @default_scheduler_options [
    oban_action_adapter: Uppy.Schedulers.ObanScheduler.CommonAction,
    upload_timeout_worker: Uppy.Schedulers.ObanScheduler.Workers.UploadTimeoutWorker,
    upload_transfer_worker: Uppy.Schedulers.ObanScheduler.Workers.UploadTransferWorker,
    worker_options: []
  ]

  def oban do
    Application.get_env(Uppy.Config.app(), Oban) || []
  end

  def scheduler do
    Keyword.merge(
      @default_scheduler_options,
      Application.get_env(
        Uppy.Config.app(),
        Uppy.Schedulers.ObanScheduler,
        []
      )
    )
  end
end
