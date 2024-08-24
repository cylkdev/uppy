defmodule Uppy.Routers.DefaultRouter do
  @moduledoc """
  ...
  """

  alias Uppy.Error

  @permanent_path_prefix ""

  @temporary_path_prefix "temp"
  @temporary_path_postfix "user"

  @doc """
  Returns a www form encoded string.

  ### Options

    * `:reverse_partition_id` - Reverses the id if true. Defaults to true.

  ### Examples

      iex> Uppy.Routers.DefaultRouter.encode_id("12")
      "21"

      iex> Uppy.Routers.DefaultRouter.encode_id("binary-id#0001")
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

    * `:reverse_partition_id` - Reverses the id if true. Defaults to true.

  ### Examples

      iex> Uppy.Routers.DefaultRouter.decode_id("21")
      "12"

      iex> Uppy.Routers.DefaultRouter.decode_id("1000%23di-yranib")
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
      String.reverse(id)
    else
      id
    end
  end

  @doc """
  Returns :ok if the string is a temporary object path.

  ### Examples

      iex> Uppy.Routers.DefaultRouter.validate_permanent_path("21-avatar/%3Cunique_identifier%3E-%3Cfilename%3E.%3Cextension%3E")
      :ok
  """
  @spec validate_permanent_path(path :: binary(), opts :: keyword()) :: :ok | {:error, ErrorMessage.t()}
  def validate_permanent_path(path, opts \\ []) do
    with {:ok, _} <- decode_permanent_path(path, opts) do
      :ok
    end
  end

  @doc """
  Returns a map describing each component of the permanent path.

  ### Examples

      iex> Uppy.Routers.DefaultRouter.decode_permanent_path("21-avatar/%3Cunique_identifier%3E-%3Cfilename%3E.%3Cextension%3E")
      {:ok, %{
        basename: "<unique_identifier>-<filename>.<extension>",
        partition_id: "12",
        resource: "avatar"
      }}

      iex> Uppy.Routers.DefaultRouter.decode_permanent_path("permanent/21-avatar/%3Cunique_identifier%3E-%3Cfilename%3E.%3Cextension%3E")
      {:ok, %{
        basename: "<unique_identifier>-<filename>.<extension>",
        partition_id: "12",
        prefix: "permanent",
        resource: "avatar"
      }}
  """
  @spec decode_permanent_path(path :: binary(), opts :: keyword()) ::
  {
    :ok,
    %{
      partition_id: binary(),
      prefix: binary(),
      resource: binary(),
      basename: binary()
    } |
    %{
      partition_id: binary(),
      resource: binary(),
      basename: binary()
    }
  }
  | {:error, ErrorMessage.t()}
  def decode_permanent_path(path, opts \\ []) do
    case Path.split(path) do
      [prefix, suffix, basename] ->
        basename = URI.decode_www_form(basename)

        with {:ok, {partition_id, resource}} <-
          split_partition(suffix, path, opts) do
          {:ok, %{
            prefix: prefix,
            partition_id: partition_id,
            resource: resource,
            basename: basename
          }}
        end

      [suffix, basename] ->
        basename = URI.decode_www_form(basename)

        with {:ok, {partition_id, resource}} <-
          split_partition(suffix, path, opts) do
          {:ok, %{
            partition_id: partition_id,
            resource: resource,
            basename: basename
          }}
        end

      _ -> {:error, Error.forbidden("failed to decode permanent path", %{path: path})}
    end
  end

  @doc """
  Returns a permanent object path string.

  ### Examples

      iex> Uppy.Routers.DefaultRouter.permanent_path(%{id: "12"})
      "21-"

      iex> Uppy.Routers.DefaultRouter.permanent_path(%{id: "12", resource: "avatar"})
      "21-avatar"

      iex> Uppy.Routers.DefaultRouter.permanent_path(%{id: "12", resource: "avatar", basename: "<unique_identifier>-<filename>.<extension>"})
      "21-avatar/%3Cunique_identifier%3E-%3Cfilename%3E.%3Cextension%3E"

      iex> Uppy.Routers.DefaultRouter.permanent_path(%{id: "12"}, permanent_path_prefix: "permanent")
      "permanent/21-"
  """
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

  def permanent_path(params) do
    permanent_path(params, [])
  end

  @doc """
  Returns a map describing each component of the temporary path.

  ### Examples

      iex> Uppy.Routers.DefaultRouter.decode_temporary_path("temp/21-user/%3Cunique_identifier%3E-%3Cfilename%3E.%3Cextension%3E")
      {:ok, %{
        basename: "<unique_identifier>-<filename>.<extension>",
        prefix: "temp",
        postfix: "user",
        partition_id: "12"
      }}
  """
  @spec decode_temporary_path(path :: binary(), opts :: keyword()) ::
    {
      :ok,
      %{
        partition_id: binary(),
        postfix: binary(),
        prefix: binary(),
        basename: binary()
      }
    }
    | {:error, ErrorMessage.t()}
  def decode_temporary_path(path, opts \\ []) do
    case Path.split(path) do
      [prefix, suffix, basename] ->
        basename = URI.decode_www_form(basename)

        with {:ok, {partition_id, postfix}} <-
          split_partition(suffix, path, opts) do
          {:ok, %{
            partition_id: partition_id,
            prefix: prefix,
            postfix: postfix,
            basename: basename
          }}
        end

      _ -> {:error, Error.forbidden("failed to decode temporary path", %{path: path})}
    end
  end

  defp split_partition(string, path, opts) do
    case String.split(string, "-") do
      [id, suffix] -> {:ok, {maybe_reverse(id, opts), suffix}}
      _ -> {:error, Error.forbidden("invalid partition", %{path: path, partition: string})}
    end
  end

  @doc """
  Returns :ok if the string is a temporary object path.

  ### Examples

      iex> Uppy.Routers.DefaultRouter.validate_temporary_path("temp/21-user/%3Cunique_identifier%3E-%3Cfilename%3E.%3Cextension%3E")
      :ok
  """
  @spec validate_temporary_path(path :: binary(), opts :: keyword()) :: :ok | {:error, ErrorMessage.t()}
  def validate_temporary_path(path, opts \\ []) do
    with {:ok, _} <- decode_temporary_path(path, opts) do
      :ok
    end
  end

  @doc """
  Returns a temporary object path string.

  ### Examples

      iex> Uppy.Routers.DefaultRouter.temporary_path(%{id: "12"})
      "temp/21-user"

      iex> Uppy.Routers.DefaultRouter.temporary_path(%{id: "12", basename: "<unique_identifier>-<filename>.<extension>"})
      "temp/21-user/%3Cunique_identifier%3E-%3Cfilename%3E.%3Cextension%3E"
  """
  @spec temporary_path(
    %{id: binary(), basename: binary()} |
    %{id: binary()},
    opts :: keyword()
  ) :: binary()
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
