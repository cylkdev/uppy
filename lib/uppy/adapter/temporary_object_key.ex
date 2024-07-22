defmodule Uppy.Adapter.TemporaryObjectKey do
  @moduledoc """
  - Encodes and decodes ids used in keys.
  - Provides functionality for searching the storage by prefix.
  """

  @doc """
  Returns `true` if the `key` starts with the object key prefix.
  """
  @callback validate_path(key :: binary()) :: {:ok, key :: binary()} | {:error, term()}

  @doc """
  ...
  """
  @callback encode_id(id :: binary()) :: binary()

  @doc """
  ...
  """
  @callback decode_id(encoded_id :: binary()) :: binary()

  @doc """
  ...
  """
  @callback prefix(id :: binary(), basename :: binary()) :: binary()

  @doc """
  ...
  """
  @callback prefix(id :: binary()) :: binary()

  @doc """
  ...
  """
  @callback prefix :: binary()
end
