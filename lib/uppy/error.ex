defmodule Uppy.Error do
  @moduledoc """
  This module provides
  """
  alias Uppy.Config

  @type code :: atom()
  @type message :: binary()
  @type details :: map() | nil
  @type error_message :: map()

  @doc """
  Executes callback functions in the configured error adapter and returns an error term.

  If the adapter exports a named function for `code` this function
  is executed as `adapter.code(message, details)` otherwise a
  3-arity function named `call` must be defined and is
  executed as `adapter.call(code, message, details)`.

  ### Examples

      iex> Uppy.Error.call(:not_found, "resource not found", %{})
      %ErrorMessage{code: :not_found, message: "resource not found", details: %{}}
  """
  @spec call(code(), message(), details()) :: error_message()
  def call(code, message, details \\ nil) do
    adapter = Config.error_adapter()

    if Code.ensure_loaded?(adapter) and function_exported?(adapter, code, 2) do
      apply(adapter, code, [message, details])
    else
      if function_exported?(adapter, :call, 3) do
        adapter.call(code, message, details)
      else
        raise """
        Uppy error handler not configured.

        To fix this error add the following configuration to you config.exs:

        ```
        # config.exs
        import Config

        config :uppy, error_adapter: ErrorMessage
        ```

        The adapter must export named functions for the error codes or a
        `call/3` callback function.

        See #{__MODULE__} module documentation for information.
        """
      end
    end
  end
end
