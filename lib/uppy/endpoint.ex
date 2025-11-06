defmodule Uppy.Endpoint do
  @doc ~S"""
  ## Usage

  First create an endpoint module:

  ```elixir
  defmodule YourApp.Endpoint do
    use Uppy.Endpoint,
      bucket: "uppy-sandbox",
      scheduler_adapter: Uppy.Endpoint.Schedulers.Oban,
      options: []

    @impl true
    def temporary_object(queryable, params) when is_atom(queryable) do
      "temp/#{module_to_name(queryable)}/#{params.filename}"
    end

    @impl true
    def permanent_object(%schema_module{} = schema_data, params) do
      "store/#{module_to_name(schema_module)}/#{schema_data.id}/#{params[:filename] || schema_data.filename}"
    end

    defp module_to_name(module) do
      module
      |> Module.split()
      |> List.last()
      |> Macro.underscore()
    end
  end
  ```

  Before calling the functions call the following:

  ```elixir
  Uppy.Repo.start_link()
  Oban.start_link([name: Uppy.Endpoint.Schedulers.Oban, repo: Uppy.Repo, queues: [uploads: 5]])
  ```

  Now you can call the functions:

  ```
  # Upload API
  filename = "5mb_#{Enum.random(0..100)}.txt"
  {:ok, record} = YourApp.Endpoint.create_upload(Uppy.Schemas.Upload, %{filename: filename})
  YourApp.Endpoint.pre_sign_upload(Uppy.Schemas.Upload, %{id: record.id})
  YourApp.Endpoint.complete_upload(Uppy.Schemas.Upload, %{id: record.id})
  YourApp.Endpoint.abort_upload(Uppy.Schemas.Upload, %{id: record.id})
  YourApp.Endpoint.delete_upload(Uppy.Schemas.Upload, %{id: record.id})
  YourApp.Endpoint.promote_upload("dest/5mb.txt", Uppy.Schemas.Upload, %{id: record.id})

  # Multipart Upload API
  filename = "5mb_#{Enum.random(0..100)}.txt"
  {:ok, record} = YourApp.Endpoint.create_multipart_upload(Uppy.Schemas.Upload, %{filename: filename})
  YourApp.Endpoint.pre_sign_upload_part(1, Uppy.Schemas.Upload, %{id: record.id})
  YourApp.Endpoint.find_parts(Uppy.Schemas.Upload, %{id: record.id})
  YourApp.Endpoint.complete_multipart_upload([%{etag: "6a94c63c450686db4da43803c1eaf4cf", part_number: 1}], Uppy.Schemas.Upload, %{id: record.id})
  YourApp.Endpoint.abort_multipart_upload(Uppy.Schemas.Upload, %{id: record.id})
  YourApp.Endpoint.delete_upload(Uppy.Schemas.Upload, %{id: record.id})
  YourApp.Endpoint.promote_upload("dest/m/5mb.txt", Uppy.Schemas.Upload, %{id: record.id})
  ```
  """
  alias Uppy.Core

  @callback bucket() :: String.t()
  @callback scheduler_adapter() :: module()
  @callback options() :: Keyword.t()
  @callback temporary_object(queryable :: module(), params :: map()) :: String.t()
  @callback permanent_object(queryable_or_struct :: module() | struct(), params :: map()) ::
              String.t()

  def bucket(adapter), do: adapter.bucket()

  def scheduler_adapter(adapter), do: adapter.scheduler_adapter()

  def options(adapter), do: adapter.options()

  def temporary_object(adapter, queryable, params) do
    adapter.temporary_object(queryable, params)
  end

  def schedule_job(adapter, job, delay_sec_or_datetime) do
    scheduler_adapter(adapter).schedule_job(job, delay_sec_or_datetime, options(adapter))
  end

  def delete_upload(adapter, queryable_or_struct, params \\ %{}) do
    adapter
    |> bucket()
    |> Core.delete_upload(queryable_or_struct, params, options(adapter))
  end

  def promote_upload(adapter, queryable_or_struct, params \\ %{}) do
    callback = &adapter.permanent_object/2

    adapter
    |> bucket()
    |> Core.promote_upload(callback, queryable_or_struct, params, options(adapter))
  end

  def complete_upload(adapter, queryable_or_struct, params \\ %{}) do
    opts = options(adapter)
    scheduler = scheduler_adapter(adapter)

    with {:ok, %schema_module{} = schema_struct} <-
           adapter
           |> bucket()
           |> Core.complete_upload(queryable_or_struct, params, opts),
         {:ok, job} <-
           scheduler.add_job(
             %{
               event: "uppy.endpoint.promote_upload",
               endpoint: adapter,
               query: schema_module,
               id: schema_struct.id
             },
             opts
           ) do
      {:ok,
       %{
         data: schema_struct,
         jobs: %{
           promote_upload: job
         }
       }}
    end
  end

  def abort_upload(adapter, queryable_or_struct, params \\ %{}) do
    adapter
    |> bucket()
    |> Core.abort_upload(queryable_or_struct, params, options(adapter))
  end

  def pre_sign_upload(adapter, queryable_or_struct, params \\ %{}) do
    adapter
    |> bucket()
    |> Core.pre_sign_upload(queryable_or_struct, params, options(adapter))
  end

  def create_upload(adapter, queryable, params \\ %{}) do
    filename = params.filename
    create_params = params |> Map.delete(:key) |> Map.put(:filename, filename)
    temp_key = temporary_object(adapter, queryable, create_params)

    adapter
    |> bucket()
    |> Core.create_upload(queryable, Map.put(create_params, :key, temp_key), options(adapter))
  end

  def complete_multipart_upload(adapter, parts, queryable_or_struct, params \\ %{}) do
    opts = options(adapter)
    scheduler = scheduler_adapter(adapter)

    with {:ok, %schema_module{} = schema_struct} <-
           adapter
           |> bucket()
           |> Core.complete_multipart_upload(parts, queryable_or_struct, params, opts),
         {:ok, job} <-
           scheduler.add_job(
             %{
               event: "uppy.endpoint.promote_upload",
               endpoint: adapter,
               query: schema_module,
               id: schema_struct.id
             },
             opts
           ) do
      {:ok,
       %{
         data: schema_struct,
         jobs: %{
           promote_upload: job
         }
       }}
    end
  end

  def abort_multipart_upload(adapter, queryable_or_struct, params \\ %{}) do
    adapter
    |> bucket()
    |> Core.abort_multipart_upload(queryable_or_struct, params, options(adapter))
  end

  def find_parts(adapter, queryable_or_struct, params \\ %{}) do
    adapter
    |> bucket()
    |> Core.find_parts(queryable_or_struct, params, options(adapter))
  end

  def pre_sign_upload_part(adapter, part_number, queryable_or_struct, params \\ %{}) do
    adapter
    |> bucket()
    |> Core.pre_sign_upload_part(part_number, queryable_or_struct, params, options(adapter))
  end

  def create_multipart_upload(adapter, queryable, params \\ %{}) do
    filename = params.filename
    create_params = params |> Map.delete(:key) |> Map.put(:filename, filename)
    temp_key = temporary_object(adapter, queryable, create_params)

    adapter
    |> bucket()
    |> Core.create_multipart_upload(
      queryable,
      Map.put(create_params, :key, temp_key),
      options(adapter)
    )
  end

  defmacro __using__(opts) do
    quote do
      opts = unquote(opts)

      alias Uppy.Endpoint

      @bucket Keyword.fetch!(opts, :bucket)
      @scheduler_adapter Keyword.get(opts, :scheduler_adapter, Uppy.Endpoint.Schedulers.Oban)
      @options Keyword.get(opts, :options, [])

      @behaviour Uppy.Endpoint

      @impl true
      def bucket, do: @bucket

      @impl true
      def scheduler_adapter, do: @scheduler_adapter

      @impl true
      def options, do: @options

      def promote_upload(queryable_or_struct, params \\ %{}) do
        Endpoint.promote_upload(__MODULE__, queryable_or_struct, params)
      end

      def delete_upload(queryable_or_struct, params \\ %{}) do
        Endpoint.delete_upload(__MODULE__, queryable_or_struct, params)
      end

      def complete_upload(queryable_or_struct, params \\ %{}) do
        Endpoint.complete_upload(__MODULE__, queryable_or_struct, params)
      end

      def abort_upload(queryable_or_struct, params \\ %{}) do
        Endpoint.abort_upload(__MODULE__, queryable_or_struct, params)
      end

      def pre_sign_upload(queryable, params) do
        Endpoint.pre_sign_upload(__MODULE__, queryable, params)
      end

      def create_upload(queryable, params \\ %{}) do
        Endpoint.create_upload(__MODULE__, queryable, params)
      end

      def complete_multipart_upload(
            parts,
            queryable_or_struct,
            params \\ %{},
            opts \\ []
          ) do
        Endpoint.complete_multipart_upload(__MODULE__, parts, queryable_or_struct, params)
      end

      def abort_multipart_upload(queryable_or_struct, params \\ %{}) do
        Endpoint.abort_multipart_upload(__MODULE__, queryable_or_struct, params)
      end

      def find_parts(queryable_or_struct, params \\ %{}) do
        Endpoint.find_parts(__MODULE__, queryable_or_struct, params)
      end

      def pre_sign_upload_part(part_number, queryable_or_struct, params \\ %{}) do
        Endpoint.pre_sign_upload_part(__MODULE__, part_number, queryable_or_struct, params)
      end

      def create_multipart_upload(queryable, params \\ %{}) do
        Endpoint.create_multipart_upload(__MODULE__, queryable, params)
      end
    end
  end
end
