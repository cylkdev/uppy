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
  Returns a error message map.

  ### Examples

      iex> Uppy.Error.bad_request("message", %{})
      %{code: :bad_request, message: "message", details: %{}}
  """
  @spec bad_request(message(), details()) :: error_message()
  def bad_request(message, details \\ nil) do
    call(:bad_request, message, details)
  end

  @doc """
  Returns a error message map.

  ### Examples

      iex> Uppy.Error.forbidden("message", %{})
      %{code: :forbidden, message: "message", details: %{}}
  """
  @spec forbidden(message(), details()) :: error_message()
  def forbidden(message, details \\ nil) do
    call(:forbidden, message, details)
  end

  @doc """
  Returns a error message map.

  ### Examples

      iex> Uppy.Error.internal_server_error("message", %{})
      %{code: :internal_server_error, message: "message", details: %{}}
  """
  @spec internal_server_error(message(), details()) :: error_message()
  def internal_server_error(message, details \\ nil) do
    call(:internal_server_error, message, details)
  end

  @doc """
  Returns a error message map.

  ### Examples

      iex> Uppy.Error.not_found("message", %{})
      %{code: :not_found, message: "message", details: %{}}
  """
  @spec not_found(message(), details()) :: error_message()
  def not_found(message, details \\ nil) do
    call(:not_found, message, details)
  end

  @doc """
  Returns a error message map.

  ### Examples

      iex> Uppy.Error.request_timeout("message", %{})
      %{code: :request_timeout, message: "message", details: %{}}
  """
  @spec request_timeout(message(), details()) :: error_message()
  def request_timeout(message, details \\ nil) do
    call(:request_timeout, message, details)
  end

  @doc """
  Returns a error message map.

  ### Examples

      iex> Uppy.Error.service_unavailable("message", %{})
      %{code: :service_unavailable, message: "message", details: %{}}
  """
  @spec service_unavailable(message(), details()) :: error_message()
  def service_unavailable(message, details \\ nil) do
    call(:service_unavailable, message, details)
  end

  @doc """
  Executes the callback function in the module configured by `:error_message_adapter` to
  create an error message. If the 2-arity function named `code` is exported this
  function with the arguments `message` and `details` otherwise the 3-arity function
  named `call` is executed with the arguments `code`, `message`, and `details`.

  ### Examples

      iex> Error.call(:not_found, "resource not found", %{})
      %{code: :not_found, message: "resource not found", details: %{}}
  """
  @spec call(code(), message(), details()) :: error_message()
  def call(code, message, details \\ nil) do
    adapter = Config.error_message_adapter()

    if Code.ensure_loaded?(adapter) and function_exported?(adapter, code, 2) do
      apply(adapter, code, [message, details])
    else
      adapter.call(code, message, details)
    end
  end
end
