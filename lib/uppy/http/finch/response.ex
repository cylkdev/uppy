defmodule Uppy.HTTP.Finch.Response do
  @moduledoc """
  Finch HTTP adapter response struct.
  """
  defstruct [
    :status,
    body: "",
    headers: [],
    request: %Finch.Request{
      host: "",
      body: "",
      query: "",
      path: "/",
      port: 80,
      method: "",
      scheme: nil,
      headers: []
    }
  ]

  @type t :: %__MODULE__{}
end
