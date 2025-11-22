defmodule Uppy.Scheduler do
  def queue_ingest_upload(params, delay \\ :none, opts \\ []) do
    scheduler_adapter(opts).queue_ingest_upload(params, delay, opts)
  end

  defp scheduler_adapter(opts) do
    opts[:scheduler_adapter] || Uppy.Schedulers.Oban
  end
end
