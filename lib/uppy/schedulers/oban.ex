defmodule Uppy.Schedulers.Oban do
  alias Uppy.Schedulers.Oban.IngestWorker

  @default_name Uppy.Schedulers.Oban

  def queue_ingest_upload(params, delay, opts) do
    name = opts[:oban][:name] || @default_name

    opts =
      case delay do
        :none -> opts
        %_{} = datetime -> Keyword.put(opts, :schedule_at, datetime)
        ttl_sec when is_integer(ttl_sec) -> Keyword.put(opts, :schedule_in, ttl_sec)
      end

    Oban.insert(name, IngestWorker.new(params), opts)
  end
end
