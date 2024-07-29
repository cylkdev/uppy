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

  @doc """
  Validates the path.
  """
  @callback validate(path :: path()) :: {:ok, term()} | {:error, term()}

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
