defmodule Uppy.Error do
  @moduledoc false
  alias Uppy.Config

  @default_error_message_adapter ErrorMessage

  def call(code, message, details, options) do
    options
    |> error_message_adapter!()
    |> apply(code, [message, details])
  end

  defp error_message_adapter!(options) do
    Keyword.get(options, :error_message_adapter, Config.error_message_adapter()) ||
      @default_error_message_adapter
  end
end
