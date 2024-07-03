defmodule Uppy.Uploader do
  alias Uppy.{
    Actions,
    Config,
    Scheduler,
    Core
  }

  @one_day_seconds 86_400
  @one_hour_seconds 3_600

  ## Adapter API

  def core(uploader), do: uploader.core()

  def core(uploader, field) do
    core = core(uploader)

    if :maps.is_key(field, core) do
      Map.fetch!(core, field)
    else
      raise ArgumentError, """
      The field #{inspect(field)} does not exist on the struct `Uppy.Core`.

      Expected one of:
      #{core |> Map.keys() |> inspect(pretty: true)}
      """
    end
  end

  def queryable(uploader), do: uploader.queryable()

  def pipeline(uploader), do: uploader.pipeline()

  ## Uploader API

  def presigned_part(uploader, params, part_number, options \\ []) do
    uploader
    |> core()
    |> Core.presigned_part(params, part_number, options)
  end

  def find_parts(uploader, params, next_part_number_marker, options \\ []) do
    uploader
    |> core()
    |> Core.find_parts(params, next_part_number_marker, options)
  end

  def complete_multipart_upload(uploader, params, parts, options \\ []) do
    core = core(uploader)

    with {:ok, complete_multipart_upload} <-
           Core.complete_multipart_upload(core, params, parts, options),
         {:ok, job} <-
           Scheduler.enqueue(
             core.scheduler,
             :move_temporary_to_permanent_upload,
             %{
               uploader: uploader,
               id: complete_multipart_upload.schema_data.id
             },
             nil,
             options
           ) do
      {:ok, Map.put(complete_multipart_upload, :job, job)}
    end
  end

  def abort_multipart_upload(uploader, params, options \\ []) do
    core = core(uploader)

    operation = fn ->
      with {:ok, abort_multipart_upload} <-
             Core.abort_multipart_upload(core, params, options),
           {:ok, job} <-
             Scheduler.enqueue(
               core.scheduler,
               :garbage_collect_object,
               %{
                 uploader: uploader,
                 key: abort_multipart_upload.schema_data.key
               },
               options[:scheduler][:garbage_collect_object] || @one_day_seconds,
               options
             ) do
        {:ok, Map.put(abort_multipart_upload, :job, job)}
      end
    end

    actions_transaction(operation, options)
  end

  def start_multipart_upload(uploader, upload_params, params \\ %{}, options \\ []) do
    core = core(uploader)

    operation = fn ->
      with {:ok, start_upload} <-
             Core.start_multipart_upload(
               core,
               upload_params,
               params,
               options
             ),
           id <-
             Map.fetch!(start_upload.schema_data, core.queryable_primary_key_source),
           {:ok, job} <-
             Scheduler.enqueue(
               core.scheduler,
               :abort_multipart_upload,
               %{uploader: uploader, id: id},
               options[:scheduler][:abort_multipart_upload] || @one_hour_seconds,
               options
             ) do
        {:ok, Map.put(start_upload, :job, job)}
      end
    end

    actions_transaction(operation, options)
  end

  def move_temporary_to_permanent_upload(uploader, params, options \\ []) do
    core = core(uploader)

    pipeline = pipeline(uploader)

    Core.move_temporary_to_permanent_upload(core, params, pipeline, options)
  end

  def complete_upload(uploader, params, options \\ []) do
    core = core(uploader)

    with {:ok, complete_upload} <- Core.complete_upload(core, params, options),
         {:ok, job} <-
           Scheduler.enqueue(
             core.scheduler,
             :move_temporary_to_permanent_upload,
             %{
               uploader: uploader,
               id: complete_upload.schema_data.id
             },
             nil,
             options
           ) do
      {:ok, Map.put(complete_upload, :job, job)}
    end
  end

  def garbage_collect_object(uploader, key, options \\ []) do
    uploader
    |> core()
    |> Core.garbage_collect_object(key, options)
  end

  def abort_upload(uploader, params, options \\ []) do
    core = core(uploader)

    operation = fn ->
      with {:ok, abort_upload} <- Core.abort_upload(core, params, options),
           {:ok, job} <-
             Scheduler.enqueue(
               core.scheduler,
               :garbage_collect_object,
               %{
                 uploader: uploader,
                 key: abort_upload.schema_data.key
               },
               options[:scheduler][:garbage_collect_object] || @one_day_seconds,
               options
             ) do
        {:ok, Map.put(abort_upload, :job, job)}
      end
    end

    actions_transaction(operation, options)
  end

  def start_upload(uploader, upload_params, params \\ %{}, options \\ []) do
    core = core(uploader)

    operation = fn ->
      with {:ok, start_upload} <- Core.start_upload(core, upload_params, params, options),
           id <-
             Map.fetch!(start_upload.schema_data, core.queryable_primary_key_source),
           {:ok, job} <-
             Scheduler.enqueue(
               core.scheduler,
               :abort_upload,
               %{uploader: uploader, id: id},
               options[:scheduler][:abort_upload] || @one_hour_seconds,
               options
             ) do
        {:ok, Map.put(start_upload, :job, job)}
      end
    end

    actions_transaction(operation, options)
  end

  defp actions_transaction(func, options) do
    Actions.transaction(Config.actions_adapter(), func, options)
  end
end
