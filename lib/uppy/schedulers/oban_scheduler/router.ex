defmodule Uppy.Schedulers.ObanScheduler.Router do
  @moduledoc false

  def lookup_instance(queue) do
    instances = config()[:instances] || %{}

    {default, instances} = Map.pop(instances, :default)

    case Enum.find(instances, default, fn {key, _} -> key === queue end) do
      nil ->
        raise """
        Oban Worker not configured for queue #{inspect(queue)}

        To fix this error you can set a default worker for all queues:

        ```
        config :uppy, Uppy.Schedulers.ObanScheduler.Router,
          instances: %{
            default: Uppy.Oban
          }
        ```

        You can also set a worker for each queue in addition to setting a default.

        ```
        config :uppy, Uppy.Schedulers.ObanScheduler.Router,
          instances: %{
            abort_expired_multipart_upload: Uppy.Oban,
            abort_expired_upload: Uppy.Oban,
            move_to_destination: Uppy.Oban,
          }
        ```
        """

      {_, val} -> val
    end
  end

  def lookup_worker(queue) do
    workers = config()[:workers] || %{}

    {default, workers} = Map.pop(workers, :default)

    case Enum.find(workers, default, fn {key, _} -> key === queue end) do
      nil ->
        raise """
        Oban Worker not configured for queue #{inspect(queue)}

        To fix this error you can set a default worker for all queues:

        ```
        config :uppy, Uppy.Schedulers.ObanScheduler.Router,
          workers: %{
            default: MyApp.ObanWorker
          }
        ```

        You can also set a worker for each queue in addition to setting a default.

        ```
        config :uppy, Uppy.Schedulers.ObanScheduler.Router,
          workers: %{
            abort_expired_multipart_upload: MyApp.ObanWorker,
            abort_expired_upload: MyApp.ObanWorker,
            move_to_destination: MyApp.ObanWorker,
          }
        ```
        """

      {_, val} -> val
    end
  end

  defp config do
    Uppy.Config.module_config(__MODULE__) || []
  end
end
