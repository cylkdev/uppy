defmodule Uppy.Adapter.TemporaryObjectKey do
  @moduledoc """
  API for managing temporary object keys.
  """

  @type id :: non_neg_integer() | binary()
  @type encoded_id :: binary()
  @type decoded_id :: binary()
  @type basename :: binary()
  @type path :: binary()
  @type prefix :: binary()
  @type options :: keyword()

  @doc """
  Validates the path.
  """
  @callback validate(path :: path(), options :: keyword()) :: {:ok, term()} | {:error, term()}

  @doc """
  Returns a string.

  This function is used to serialize object keys going into storage.
  """
  @callback encode_id(id :: id()) :: encoded_id()

  @doc """
  Returns a string.

  This function is used to de-serialize object keys in storage.
  """
  @callback decode_id(encoded_id :: encoded_id()) :: decoded_id()

  @doc """
  Returns the prefix of the object path as a string.

  The returned string must be a valid path that includes the `id`, `resource_name`, and `basename`
  encoded as URL-friendly values (see `URI.encode_www_form/1`).

  Examples:

  ```
  <prefix>/<id>-<postfix>/<basename>
  temp/1-user/unique_identifier-image.jpeg

  <prefix>/<id>-<postfix>/
  temp/1-user/

  <prefix>/
  temp/
  ```
  """
  @callback prefix(id :: id(), basename :: basename()) :: prefix()

  @doc """
  See `c:Uppy.Adapter.TemporaryObjectKey.prefix/2` for more information.
  """
  @callback prefix(id :: id()) :: prefix()

  @doc """
  See `c:Uppy.Adapter.TemporaryObjectKey.prefix/2` for more information.
  """
  @callback prefix :: prefix()
end
