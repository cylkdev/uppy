defmodule Uppy.Adapter.PermanentObjectKey do
  @moduledoc """
  API for managing permanent object keys.
  """

  @type id :: non_neg_integer() | binary()
  @type encoded_id :: binary()
  @type decoded_id :: binary()
  @type resource_name :: binary()
  @type basename :: binary()
  @type path :: binary()
  @type prefix :: binary()

  @doc """
  Validates the path.
  """
  @callback validate(path :: path()) :: {:ok, term()} | {:error, term()}

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
  <prefix>/<id>-<postfix>/<resource_name>/<basename>
  private/1-organization/organization-avatars/unique_identifier-image.jpeg

  <prefix>/<id>-<postfix>/<resource_name>/
  private/1-organization/organization-avatars/

  <prefix>/<id>-<postfix>/
  private/1-organization/
  ```
  """
  @callback prefix(id :: id(), resource_name :: resource_name(), basename :: basename()) ::
              prefix()

  @doc """
  See `c:Uppy.Adapter.PermanentObjectKey.prefix/3` for more information.
  """
  @callback prefix(id :: id(), resource_name :: resource_name()) :: prefix()

  @doc """
  See `c:Uppy.Adapter.PermanentObjectKey.prefix/3` for more information.
  """
  @callback prefix(id :: id()) :: prefix()

  @doc """
  See `c:Uppy.Adapter.PermanentObjectKey.prefix/3` for more information.
  """
  @callback prefix :: prefix()
end
