defmodule Uppy.Endpoint.Schedulers.Oban do
  @default_oban_options [
    worker: Uppy.Endpoint.Schedulers.Oban.Worker,
    name: Uppy.Endpoint.Schedulers.Oban
  ]

  def schedule_job(job, delay_sec_or_datetime, opts \\ []) do
    Cue.schedule_job(job, %{}, delay_sec_or_datetime, opts)
  end

  def add_job(params, opts \\ []) do
    Cue.add_job(params, with_default_options(opts))
  end

  defp with_default_options(opts) do
    Keyword.update(
      opts,
      :oban,
      @default_oban_options,
      &Keyword.merge(@default_oban_options, &1)
    )
  end
end
