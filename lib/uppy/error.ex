defmodule Uppy.Error do
  @moduledoc """
  Error Message Adapter Interface
  """
  alias Uppy.Config

  @type code :: atom()
  @type message :: binary()
  @type details :: map() | nil
  @type error_message :: %{
          optional(any()) => any(),
          code: code(),
          message: message(),
          details: details()
        }

  @doc """
  Executes the callback function in the module configured by `:error_adapter` to
  create an error message. If the 2-arity function named `code` is exported this
  function with the arguments `message` and `details` otherwise the 3-arity function
  named `call` is executed with the arguments `code`, `message`, and `details`.

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
      adapter.call(code, message, details)
    end
  end
end
