defmodule Uppy.Endpoint.Schedulers.Oban.Worker do
  use Oban.Worker,
    queue: :uploads,
    max_attempts: 20,
    unique: [period: 300]

  @logger_prefix "Uppy.Endpoint.Schedulers.Oban.Worker"

  alias Uppy.Endpoint

  def perform(
        %Oban.Job{
          args: %{"event" => "uppy.endpoint.promote_upload", "endpoint" => endpoint},
          attempt: attempt
        } = job
      )
      when attempt > 3 do
    endpoint = maybe_string_to_module(endpoint)

    Endpoint.schedule_job(endpoint, job, 60 * attempt)
  end

  def perform(
        %Oban.Job{
          args: %{
            "event" => "uppy.endpoint.promote_upload",
            "endpoint" => endpoint,
            "query" => query,
            "id" => id
          }
        } = job
      ) do
    endpoint = maybe_string_to_module(endpoint)
    query = maybe_string_to_module(query)
    id = maybe_string_to_integer(id)

    result = Endpoint.promote_upload(endpoint, query, %{id: id})

    Uppy.Logger.info(@logger_prefix, """
    Promote upload executed:

    job:

    #{inspect(job, pretty: true)}

    result:

    #{inspect(result, pretty: true)}
    """)

    result
  end

  defp maybe_string_to_module(string) when is_binary(string) do
    string |> String.split(".") |> Module.safe_concat()
  end

  defp maybe_string_to_module(term) do
    term
  end

  defp maybe_string_to_integer(string) when is_binary(string) do
    String.to_integer(string)
  end

  defp maybe_string_to_integer(term) do
    term
  end
end
