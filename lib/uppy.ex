defmodule Uppy do
  @moduledoc """
  Application.ensure_all_started(:postgrex)
  Application.ensure_all_started(:ecto)
  Application.ensure_all_started(:oban)
  Uppy.Support.Repo.start_link()

  ```elixir
  defmodule MyApp.Uploader do
    use Uppy.Uploader,
      resource_name: "user_avatar",
      bucket: "my-app-bucket",
      query: {"user_avatar_file_infos", Uppy.Support.Schemas.FileInfoAbstract},
      path_params: %{
        permanent_object: %{
          reverse_partition_id: true,
          partition_name: "company"
        },
        temporary_object: %{
          partition_name: "user",
          basename_prefix: "temp"
        }
      }
  end
  ```

  ```elixir
  defmodule MyApp.Bridge do
    use Uppy.Bridge,
      http_adapter: Uppy.HTTP.Finch,
      scheduler_adapter: Uppy.Schedulers.Oban,
      storage_adapter: Uppy.Storages.S3,
      options: [scheduler: [repo: MyApp.Repo]]
  end
  ```

  ```elixir
  Uppy.start_link([MyApp.Bridge])
  ```
  """
  alias Uppy.{Bridge, Core, Uploader}

  @doc """
  ...
  """
  def start_link(name \\ __MODULE__, bridges, opts \\ []) do
    Uppy.Supervisor.start_link(name, bridges, opts)
  end

  @doc """
  ...
  """
  def child_spec(opts) do
    opts
    |> Keyword.put_new(:name, __MODULE__)
    |> Uppy.Supervisor.child_spec()
  end

  @doc """
  ...
  """
  def move_to_destination(uploader, dest_object, params_or_struct, opts) do
    {nil_or_bridge, uploader} = bridge_invoc(uploader)

    Uploader.move_to_destination(
      uploader,
      dest_object,
      params_or_struct,
      put_bridge_opts(opts, nil_or_bridge)
    )
  end

  @doc """
  ...
  """
  def move_to_destination(bucket, query, dest_object, params_or_struct, opts) do
    Core.move_to_destination(bucket, query, dest_object, params_or_struct, put_bridge_opts(opts))
  end

  @doc """
  ...
  """
  def find_parts(uploader, params_or_struct, opts) do
    {nil_or_bridge, uploader} = bridge_invoc(uploader)

    Uploader.find_parts(uploader, params_or_struct, put_bridge_opts(opts, nil_or_bridge))
  end

  @doc """
  ...
  """
  def find_parts(bucket, query, params_or_struct, opts) do
    Core.find_parts(bucket, query, params_or_struct, put_bridge_opts(opts))
  end

  @doc """
  ...
  """
  def sign_part(uploader, params_or_struct, part_number, opts) do
    {nil_or_bridge, uploader} = bridge_invoc(uploader)

    Uploader.sign_part(
      uploader,
      params_or_struct,
      part_number,
      put_bridge_opts(opts, nil_or_bridge)
    )
  end

  @doc """
  ...
  """
  def sign_part(bucket, query, params_or_struct, part_number, opts) do
    Core.sign_part(bucket, query, params_or_struct, part_number, put_bridge_opts(opts))
  end

  @doc """
  ...
  """
  def complete_multipart_upload(
        bucket,
        query,
        find_params,
        update_params,
        parts,
        path_params,
        opts
      ) do
    Core.complete_multipart_upload(
      bucket,
      query,
      find_params,
      update_params,
      parts,
      path_params,
      put_bridge_opts(opts)
    )
  end

  @doc """
  ...
  """
  def complete_multipart_upload(
        uploader,
        params_or_struct,
        update_params,
        parts,
        path_params,
        opts
      ) do
        {nil_or_bridge, uploader} = bridge_invoc(uploader)

    Uploader.complete_multipart_upload(
      uploader,
      params_or_struct,
      update_params,
      parts,
      path_params,
      put_bridge_opts(opts, nil_or_bridge)
    )
  end

  @doc """
  ...
  """
  def abort_multipart_upload(uploader, params_or_struct, update_params, opts) do
    {nil_or_bridge, uploader} = bridge_invoc(uploader)

    Uploader.abort_multipart_upload(
      uploader,
      params_or_struct,
      update_params,
      put_bridge_opts(opts, nil_or_bridge)
    )
  end

  @doc """
  ...
  """
  def abort_multipart_upload(bucket, query, find_params, update_params, opts) do
    Core.abort_multipart_upload(bucket, query, find_params, update_params, put_bridge_opts(opts))
  end

  @doc """
  ...
  """
  def create_multipart_upload(uploader, filename, create_params, path_params, opts) do
    {nil_or_bridge, uploader} = bridge_invoc(uploader)

    Uploader.create_multipart_upload(
      uploader,
      filename,
      create_params,
      path_params,
      put_bridge_opts(opts, nil_or_bridge)
    )
  end

  @doc """
  ...
  """
  def create_multipart_upload(
        bucket,
        query,
        filename,
        create_params,
        path_params,
        opts
      ) do
    Core.create_multipart_upload(
      bucket,
      query,
      filename,
      create_params,
      path_params,
      put_bridge_opts(opts)
    )
  end

  @doc """
  ...
  """
  def complete_upload(uploader, params_or_struct, update_params, path_params, opts) do
    {nil_or_bridge, uploader} = bridge_invoc(uploader)

    Uploader.complete_upload(
      uploader,
      params_or_struct,
      update_params,
      path_params,
      put_bridge_opts(opts, nil_or_bridge)
    )
  end

  @doc """
  ...
  """
  def complete_upload(
        bucket,
        query,
        params_or_struct,
        update_params,
        path_params,
        opts
      ) do
    Core.complete_upload(
      bucket,
      query,
      params_or_struct,
      update_params,
      path_params,
      put_bridge_opts(opts)
    )
  end

  @doc """
  ...
  """
  def abort_upload(uploader, filename, params, opts) do
    {nil_or_bridge, uploader} = bridge_invoc(uploader)

    Uploader.abort_upload(
      uploader,
      filename,
      params,
      put_bridge_opts(opts, nil_or_bridge)
    )
  end

  @doc """
  ...
  """
  def abort_upload(bucket, query, params_or_struct, update_params, opts) do
    Core.abort_upload(
      bucket,
      query,
      params_or_struct,
      update_params,
      put_bridge_opts(opts)
    )
  end

  @doc """
  ...
  """
  def create_upload(uploader, filename, create_params, path_params, opts) do
    {nil_or_bridge, uploader} = bridge_invoc(uploader)

    Uploader.create_upload(
      uploader,
      filename,
      create_params,
      path_params,
      put_bridge_opts(opts, nil_or_bridge)
    )
  end

  @doc """
  ...
  """
  def create_upload(bucket, query, filename, create_params, path_params, opts) do
    Core.create_upload(
      bucket,
      query,
      filename,
      create_params,
      path_params,
      put_bridge_opts(opts)
    )
  end

  defp put_bridge_opts(opts) do
    if Keyword.has_key?(opts, :bridge) do
      opts
      |> Keyword.fetch!(:bridge)
      |> Bridge.build_options()
      |> Keyword.merge(opts)
    else
      opts
    end
  end

  defp put_bridge_opts(opts, nil), do: put_bridge_opts(opts)
  defp put_bridge_opts(opts, bridge) do
    bridge
    |> Bridge.build_options()
    |> Keyword.merge(opts)
  end

  defp bridge_invoc({bridge, uploader}), do: {bridge, uploader}
  defp bridge_invoc(uploader), do: {nil, uploader}
end
