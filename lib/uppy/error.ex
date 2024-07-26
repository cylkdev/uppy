defmodule Uppy.Error do
  @moduledoc false
  alias Uppy.Config

  def call(code, message, details) do
    apply(Config.error_message_adapter(), code, [message, details])
  end
end
