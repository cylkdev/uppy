if Uppy.Utils.application_loaded?(:oban) do
  defmodule Uppy.Schedulers.Oban.AbortUploadWorker do
    @moduledoc false
    use Oban.Worker,
      queue: :abort_upload,
      unique: [
        period: 300,
        states: [:available, :scheduled, :executing]
      ]

    alias Uppy.Core
    alias Uppy.Schedulers.Oban.{
      EventName,
      ObanUtil
    }

    @event_abort_multipart_upload EventName.abort_multipart_upload()
    @event_abort_upload EventName.abort_upload()

    def perform(%Oban.Job{
      args: %{
        "event" => @event_abort_multipart_upload,
        "bucket" => bucket,
        "id" => id,
        "query" => query
      }
    }) do
      Core.abort_multipart_upload(bucket, ObanUtil.decode_binary_to_term(query), %{id: id})
    end

    def perform(%Oban.Job{
      args: %{
        "event" => @event_abort_upload,
        "bucket" => bucket,
        "id" => id,
        "query" => query
      }
    }) do
      Core.abort_upload(bucket, ObanUtil.decode_binary_to_term(query), %{id: id})
    end

    def queue_abort_multipart_upload(bucket, query, id, schedule, opts) do
      %{
        event: @event_abort_multipart_upload,
        bucket: bucket,
        id: id,
        query: ObanUtil.encode_term_to_binary(query)
      }
      |> new()
      |> ObanUtil.insert(schedule, opts)
    end

    def queue_abort_upload(bucket, query, id, schedule, opts) do
      %{
        event: @event_abort_upload,
        bucket: bucket,
        id: id,
        query: ObanUtil.encode_term_to_binary(query)
      }
      |> new()
      |> ObanUtil.insert(schedule, opts)
    end
  end
end
