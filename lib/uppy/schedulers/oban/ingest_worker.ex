defmodule Uppy.Schedulers.Oban.IngestWorker do
  use Oban.Worker,
    queue: :ingest,
    max_attempts: 10,
    unique: [period: 300]

  @logger_prefix "Uppy.Schedulers.Oban.IngestWorker"

  def perform(%Oban.Job{attempt: attempt}) when attempt > 3 do
    {:snooze, attempt * 60}
  end

  def perform(%Oban.Job{args: %{"endpoint" => endpoint, "key" => request_key}}) do
    response = endpoint |> string_to_module() |> Uppy.Endpoint.handle_ingest(request_key)

    Uppy.Logger.debug(
      @logger_prefix,
      """
      Ingestion callback executed for endpoint.

      endpoint: #{endpoint}
      key: #{request_key}

      response:

      #{inspect(response, pretty: true)}
      """
    )

    response
  end

  defp string_to_module(string) do
    string
    |> String.split(".", trim: true)
    |> Module.safe_concat()
  end
end
