defmodule Uppy.Resolution do
  @moduledoc false

  @type t :: %__MODULE__{
          state: :unresolved | :resolved,
          bucket: binary(),
          query: term(),
          value: Ecto.Schema.t(),
          arguments: map()
        }

  defstruct [
    :bucket,
    :query,
    :value,
    :arguments,
    state: :unresolved
  ]

  @spec new!(params :: map() | keyword()) :: t()
  def new!(params) do
    struct!(__MODULE__, params)
  end
end
