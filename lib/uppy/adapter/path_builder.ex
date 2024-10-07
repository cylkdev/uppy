defmodule Uppy.Adapter.PathBuilder do
  @moduledoc """
  ...
  """

  @type opts :: Uppy.opts()

  @type id :: binary()
  @type basename :: binary()
  @type path :: binary()
  @type resource :: binary()
  @type prefix :: binary()
  @type postfix :: binary()

  @typedoc """
  ...
  """
  @type permanent_path_params :: %{
    optional(:basename) => basename(),
    optional(:resource) => resource(),
    id: id()
  }

  @typedoc """
  ...
  """
  @type permanent_path_descriptor :: %{
    optional(:prefix) => binary(),
    id: binary(),
    resource: binary(),
    basename: binary()
  }

  @typedoc """
  ...
  """
  @type temporary_path_params :: %{
    optional(:basename) => basename(),
    id: id()
  }

  @typedoc """
  ...
  """
  @type temporary_path_descriptor :: %{
    id: id(),
    postfix: postfix(),
    prefix: prefix(),
    basename: basename()
  }

  @doc """
  ...
  """
  @callback decode_permanent_path(path :: path(), opts :: opts()) ::
    {:ok, permanent_path_descriptor()} | {:error, term()}

  @doc """
  ...
  """
  @callback validate_permanent_path(path :: path(), opts :: opts()) ::
    :ok | {:error, term()}

  @doc """
  ...
  """
  @callback permanent_path(params :: permanent_path_params(), opts :: opts()) :: binary()

  @doc """
  ...
  """
  @callback decode_temporary_path(path :: path(), opts :: opts()) ::
    {:ok, temporary_path_descriptor()} | {:error, term()}

  @doc """
  ...
  """
  @callback validate_temporary_path(path :: path(), opts :: opts()) ::
    :ok | {:error, term()}

  @doc """
  ...
  """
  @callback temporary_path(params :: temporary_path_params(), opts :: opts()) :: binary()
end
