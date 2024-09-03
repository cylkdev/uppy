defmodule Uppy.PathBuilder do
  @moduledoc """
  ...
  """

  @type permanent_path_descriptor :: Uppy.Adapter.PathBuilder.permanent_path_descriptor()

  @default_path_builder Uppy.PathBuilders.UploadPathBuilder

  @spec encode_id(id :: binary(), opts :: keyword()) :: binary()
  def encode_id(id, opts \\ []) do
    adapter!(opts).encode_id(id, opts)
  end

  @spec decode_id(id :: binary(), opts :: keyword()) :: binary()
  def decode_id(id, opts \\ []) do
    adapter!(opts).decode_id(id, opts)
  end

  @doc """
  Returns a map describing each component of the permanent path.

  ### Examples

      iex> Uppy.PathBuilder.decode_permanent_path("21-avatar/%3Cunique_identifier%3E-%3Cfilename%3E.%3Cextension%3E")
      {:ok, %{
        basename: "<unique_identifier>-<filename>.<extension>",
        id: "12",
        resource: "avatar"
      }}

      iex> Uppy.PathBuilder.decode_permanent_path("permanent/21-avatar/%3Cunique_identifier%3E-%3Cfilename%3E.%3Cextension%3E")
      {:ok, %{
        basename: "<unique_identifier>-<filename>.<extension>",
        id: "12",
        prefix: "permanent",
        resource: "avatar"
      }}
  """
  @spec decode_permanent_path(path :: binary(), opts :: keyword()) ::
    {:ok, permanent_path_descriptor()} | {:error, term()}
  def decode_permanent_path(path, opts \\ []) do
    adapter!(opts).decode_permanent_path(path, opts)
  end

  @doc """
  Returns :ok if the string is a temporary object path.

  ### Examples

      iex> Uppy.PathBuilder.validate_permanent_path("21-avatar/%3Cunique_identifier%3E-%3Cfilename%3E.%3Cextension%3E")
      :ok
  """
  @spec validate_permanent_path(path :: binary(), opts :: keyword()) :: :ok | {:error, term()}
  def validate_permanent_path(path, opts \\ []) do
    adapter!(opts).validate_permanent_path(path, opts)
  end

  @doc """
  Returns a permanent object path string.

  ### Examples

      iex> Uppy.PathBuilder.permanent_path(%{id: "12"})
      "21-"

      iex> Uppy.PathBuilder.permanent_path(%{id: "12", resource: "avatar"})
      "21-avatar"

      iex> Uppy.PathBuilder.permanent_path(%{id: "12", resource: "avatar", basename: "<unique_identifier>-<filename>.<extension>"})
      "21-avatar/%3Cunique_identifier%3E-%3Cfilename%3E.%3Cextension%3E"

      iex> Uppy.PathBuilder.permanent_path(%{id: "12"}, permanent_path_prefix: "permanent")
      "permanent/21-"
  """
  def permanent_path(params, opts \\ []) do
    adapter!(opts).permanent_path(params, opts)
  end

  @doc """
  Returns a map describing each component of the temporary path.

  ### Examples

      iex> Uppy.PathBuilder.decode_temporary_path("temp/21-user/%3Cunique_identifier%3E-%3Cfilename%3E.%3Cextension%3E")
      {:ok, %{
        basename: "<unique_identifier>-<filename>.<extension>",
        prefix: "temp",
        postfix: "user",
        id: "12"
      }}
  """
  @spec decode_temporary_path(path :: binary(), opts :: keyword()) ::
    {
      :ok,
      %{
        id: binary(),
        postfix: binary(),
        prefix: binary(),
        basename: binary()
      }
    }
    | {:error, term()}
  def decode_temporary_path(path, opts \\ []) do
    adapter!(opts).decode_temporary_path(path, opts)
  end

  @doc """
  Returns :ok if the string is a temporary object path.

  ### Examples

      iex> Uppy.PathBuilder.validate_temporary_path("temp/21-user/%3Cunique_identifier%3E-%3Cfilename%3E.%3Cextension%3E")
      :ok
  """
  @spec validate_temporary_path(path :: binary(), opts :: keyword()) :: :ok | {:error, term()}
  def validate_temporary_path(path, opts \\ []) do
    adapter!(opts).validate_temporary_path(path, opts)
  end

  @doc """
  Returns a temporary object path string.

  ### Examples

      iex> Uppy.PathBuilder.temporary_path(%{id: "12"})
      "temp/21-user"

      iex> Uppy.PathBuilder.temporary_path(%{id: "12", basename: "<unique_identifier>-<filename>.<extension>"})
      "temp/21-user/%3Cunique_identifier%3E-%3Cfilename%3E.%3Cextension%3E"
  """
  @spec temporary_path(
    %{id: binary(), basename: binary()} |
    %{id: binary()},
    opts :: keyword()
  ) :: binary()
  def temporary_path(params, opts \\ []) do
    adapter!(opts).temporary_path(params, opts)
  end

  defp adapter!(opts) do
    opts[:permanent_path_builder] || @default_path_builder
  end
end
