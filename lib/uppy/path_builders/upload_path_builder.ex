defmodule Uppy.PathBuilders.UploadPathBuilder do
  @moduledoc """
  ...
  """
  alias Uppy.Error

  @type options :: Uppy.options()
  @type permanent_path_params :: Uppy.Adapter.PathBuilder.permanent_path_params()
  @type permanent_path_descriptor :: Uppy.Adapter.PathBuilder.permanent_path_descriptor()
  @type temporary_path_params :: Uppy.Adapter.PathBuilder.temporary_path_params()
  @type temporary_path_descriptor :: Uppy.Adapter.PathBuilder.temporary_path_descriptor()

  @behaviour Uppy.Adapter.PathBuilder

  @permanent_path_prefix ""

  @temporary_path_prefix "temp"
  @temporary_path_postfix "user"

  @doc """
  Returns a www form encoded string.

  ### Options

    * `:reverse_id` - Reverses the id if true. Defaults to true.

  ### Examples

      iex> Uppy.PathBuilders.UploadPathBuilder.encode_id("12")
      "21"

      iex> Uppy.PathBuilders.UploadPathBuilder.encode_id("binary-id#0001")
      "1000%23di-yranib"
  """
  @spec encode_id(id :: binary(), opts :: keyword()) :: binary()
  def encode_id(id, opts \\ []) do
    id
    |> maybe_reverse(opts)
    |> URI.encode_www_form()
  end

  @doc """
  Returns a decoded www form encoded string.

  ### Options

    * `:reverse_id` - Reverses the id if true. Defaults to true.

  ### Examples

      iex> Uppy.PathBuilders.UploadPathBuilder.decode_id("21")
      "12"

      iex> Uppy.PathBuilders.UploadPathBuilder.decode_id("1000%23di-yranib")
      "binary-id#0001"
  """
  @spec decode_id(encoded_id :: binary(), opts :: keyword()) :: binary()
  def decode_id(encoded_id, opts \\ []) do
    encoded_id
    |> URI.decode_www_form()
    |> maybe_reverse(opts)
  end

  defp maybe_reverse(id, opts) do
    if Keyword.get(opts, :reverse_ids?, true) do
      id |> to_string() |> String.reverse()
    else
      id
    end
  end

  @doc """
  Returns a map describing each component of the permanent path.

  ### Examples

      iex> Uppy.PathBuilders.UploadPathBuilder.decode_permanent_path("21-avatar/%3Cunique_identifier%3E-%3Cfilename%3E.%3Cextension%3E")
      {:ok, %{
        basename: "<unique_identifier>-<filename>.<extension>",
        id: "12",
        resource: "avatar"
      }}

      iex> Uppy.PathBuilders.UploadPathBuilder.decode_permanent_path("permanent/21-avatar/%3Cunique_identifier%3E-%3Cfilename%3E.%3Cextension%3E")
      {:ok, %{
        basename: "<unique_identifier>-<filename>.<extension>",
        id: "12",
        prefix: "permanent",
        resource: "avatar"
      }}
  """
  @impl true
  @spec decode_permanent_path(path :: binary(), opts :: keyword()) ::
    {:ok, permanent_path_descriptor()} | {:error, term()}
  def decode_permanent_path(path, opts \\ []) do
    case Path.split(path) do
      [prefix, suffix, basename] ->
        basename = URI.decode_www_form(basename)

        with {:ok, {id, resource}} <-
          split_partition(suffix, path, opts) do
          {:ok, %{
            prefix: prefix,
            id: id,
            resource: resource,
            basename: basename
          }}
        end

      [suffix, basename] ->
        basename = URI.decode_www_form(basename)

        with {:ok, {id, resource}} <-
          split_partition(suffix, path, opts) do
          {:ok, %{
            id: id,
            resource: resource,
            basename: basename
          }}
        end

      _ -> {:error, Error.forbidden("failed to decode permanent path", %{path: path})}
    end
  end

  @doc """
  Returns :ok if the string is a temporary object path.

  ### Examples

      iex> Uppy.PathBuilders.UploadPathBuilder.validate_permanent_path("21-avatar/%3Cunique_identifier%3E-%3Cfilename%3E.%3Cextension%3E")
      :ok
  """
  @impl true
  @spec validate_permanent_path(path :: binary(), opts :: keyword()) :: :ok | {:error, term()}
  def validate_permanent_path(path, opts \\ []) do
    with {:ok, _} <- decode_permanent_path(path, opts) |> IO.inspect() do
      :ok
    end
  end

  @doc """
  Returns a permanent object path string.

  ### Examples

      iex> Uppy.PathBuilders.UploadPathBuilder.permanent_path(%{id: "12"})
      "21-"

      iex> Uppy.PathBuilders.UploadPathBuilder.permanent_path(%{id: "12", resource: "avatar"})
      "21-avatar"

      iex> Uppy.PathBuilders.UploadPathBuilder.permanent_path(%{id: "12", resource: "avatar", basename: "<unique_identifier>-<filename>.<extension>"})
      "21-avatar/%3Cunique_identifier%3E-%3Cfilename%3E.%3Cextension%3E"

      iex> Uppy.PathBuilders.UploadPathBuilder.permanent_path(%{id: "12"}, permanent_path_prefix: "permanent")
      "permanent/21-"
  """
  @impl true
  @spec permanent_path(params :: permanent_path_params(), opts :: options()) :: binary()
  def permanent_path(params, opts \\ [])

  def permanent_path(%{id: id, resource: resource, basename: basename}, opts) do
    path = permanent_path(%{id: id, resource: resource}, opts)

    basename = URI.encode_www_form(basename)

    Path.join([path, basename])
  end

  def permanent_path(%{id: id, resource: resource}, opts) do
    path = permanent_path(%{id: id}, opts)

    path <> resource
  end

  def permanent_path(%{id: id}, opts) do
    prefix = permanent_prefix!(opts)
    id = encode_id(id, opts)

    Path.join([prefix, "#{id}-"])
  end

  @doc """
  Returns a map describing each component of the temporary path.

  ### Examples

      iex> Uppy.PathBuilders.UploadPathBuilder.decode_temporary_path("temp/21-user/%3Cunique_identifier%3E-%3Cfilename%3E.%3Cextension%3E")
      {:ok, %{
        basename: "<unique_identifier>-<filename>.<extension>",
        prefix: "temp",
        postfix: "user",
        id: "12"
      }}
  """
  @impl true
  @spec decode_temporary_path(path :: binary(), opts :: keyword()) ::
    {:ok, temporary_path_descriptor()} | {:error, term()}
  def decode_temporary_path(path, opts \\ []) do
    case Path.split(path) do
      [prefix, suffix, basename] ->
        basename = URI.decode_www_form(basename)

        with {:ok, {id, postfix}} <-
          split_partition(suffix, path, opts) do
          {:ok, %{
            id: id,
            prefix: prefix,
            postfix: postfix,
            basename: basename
          }}
        end

      _ -> {:error, Error.forbidden("failed to decode temporary path", %{path: path})}
    end
  end

  @doc """
  Returns :ok if the string is a temporary object path.

  ### Examples

      iex> Uppy.PathBuilders.UploadPathBuilder.validate_temporary_path("temp/21-user/%3Cunique_identifier%3E-%3Cfilename%3E.%3Cextension%3E")
      :ok
  """
  @impl true
  @spec validate_temporary_path(path :: binary(), opts :: keyword()) :: :ok | {:error, term()}
  def validate_temporary_path(path, opts \\ []) do
    with {:ok, _} <- decode_temporary_path(path, opts) do
      :ok
    end
  end

  @doc """
  Returns a temporary object path string.

  ### Examples

      iex> Uppy.PathBuilders.UploadPathBuilder.temporary_path(%{id: "12"})
      "temp/21-user"

      iex> Uppy.PathBuilders.UploadPathBuilder.temporary_path(%{id: "12", basename: "<unique_identifier>-<filename>.<extension>"})
      "temp/21-user/%3Cunique_identifier%3E-%3Cfilename%3E.%3Cextension%3E"
  """
  @impl true
  @spec temporary_path(params :: temporary_path_params(), opts :: options()) :: binary()
  def temporary_path(%{id: id, basename: basename}, opts) do
    path = temporary_path(%{id: id}, opts)

    encoded_basename = URI.encode_www_form(basename)

    Path.join([path, encoded_basename])
  end

  def temporary_path(%{id: id}, opts) do
    prefix = temporary_prefix!(opts)
    postfix = temporary_postfix!(opts)
    id = encode_id(id, opts)

    Path.join([prefix, "#{id}-#{postfix}"])
  end

  def temporary_path(params) do
    temporary_path(params, [])
  end

  defp split_partition(string, path, opts) do
    case String.split(string, "-") do
      [id, suffix] -> {:ok, {maybe_reverse(id, opts), suffix}}
      _ -> {:error, Error.forbidden("invalid partition", %{path: path, partition: string})}
    end
  end

  defp permanent_prefix!(opts) do
    opts[:permanent_path_prefix] || @permanent_path_prefix
  end

  defp temporary_prefix!(opts) do
    opts[:temporary_path_prefix] || @temporary_path_prefix
  end

  defp temporary_postfix!(opts) do
    opts[:temporary_path_postfix] || @temporary_path_postfix
  end
end
