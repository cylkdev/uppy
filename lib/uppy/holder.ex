defmodule Uppy.Holder do
  @moduledoc false

  def fetch_id!(%_{} = holder, opts \\ []) do
    source = holder_association_key!(opts)

    case Map.get(holder, source) do
      id when is_binary(id) or is_integer(id) -> id
      term -> raise "Expected partition id to be a string or integer, got: #{inspect(term)}"
    end
  end

  defp holder_association_key!(opts) do
    with nil <- Keyword.get(opts, :holder_association_key, :organization_id) do
      raise "option `:holder_association_key` cannot be `nil` for phase #{__MODULE__}"
    end
  end
end
