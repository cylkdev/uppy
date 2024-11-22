defmodule Uppy.Route do
  @moduledoc """
  Object route
  """

  @type adapter :: module()
  @type params :: term()
  @type basename :: binary()
  @type path :: binary()

  @doc """
  ...
  """
  @callback path(basename :: basename(), params :: params()) :: binary()

  @doc """
  ...
  """
  @callback validate(path :: path()) :: {:ok, term()} | {:error, term()}

  @doc """
  ...
  """
  @callback valid?(path :: path()) :: boolean()

  @doc """
  Invokes callback function `__config__/0`.

  ### Examples

      iex> Uppy.Route.__config__(Uppy.Routes.TemporaryRoute)
      []
  """
  def __config__(adapter), do: adapter.__config__()

  @doc """
  Invokes callback function `valid?/1`.

  ### Examples

      iex> Uppy.Route.valid?(Uppy.Routes.TemporaryRoute, "temp/01-user/unique_identifier-image.jpeg")
      true
  """
  @spec valid?(
          adapter :: adapter(),
          path :: path()
        ) :: boolean()
  def valid?(adapter, path) do
    adapter.valid?(path)
  end

  @doc """
  Invokes callback function `validate/1`.

  ### Examples

      iex> Uppy.Route.validate(Uppy.Routes.TemporaryRoute, "temp/01-user/unique_identifier-image.jpeg")
      {:ok, %{
        prefix: "temp",
        partition_id: "10",
        partition_name: "user",
        basename: "unique_identifier-image.jpeg"
      }}
  """
  @spec validate(
          adapter :: adapter(),
          path :: path()
        ) :: {:ok, term()} | {:error, term()}
  def validate(adapter, path) do
    adapter.validate(path)
  end

  @doc """
  Invokes callback function `path/2`.

  ### Examples

      iex> Uppy.Route.path(Uppy.Routes.TemporaryRoute, "unique_identifier-image.jpeg", %{user_id: 10})
      "temp/01-user/unique_identifier-image.jpeg"
  """
  @spec path(
          adapter :: adapter(),
          basename :: basename(),
          params :: params()
        ) :: path()
  def path(adapter, basename, params) do
    adapter.path(basename, params)
  end
end
