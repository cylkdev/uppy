defmodule Uppy.Schedulers.Oban do
  alias Uppy.Schedulers.Oban.IngestWorker

  @default_name __MODULE__
  @compiled_opts Application.compile_env(:uppy, __MODULE__, [])
  @name Keyword.get(@compiled_opts, :name, @default_name)

  def queue_ingest_upload(params, delay, opts) do
    opts = put_schedule_opt(opts, delay)

    opts
    |> Keyword.get(:oban_name, @name)
    |> Oban.insert(IngestWorker.new(params), opts)
  end

  defp put_schedule_opt(opts, delay) do
    case delay do
      :none -> opts
      %_{} = datetime -> Keyword.put(opts, :schedule_at, datetime)
      ttl_sec when is_integer(ttl_sec) -> Keyword.put(opts, :schedule_in, ttl_sec)
    end
  end
end
