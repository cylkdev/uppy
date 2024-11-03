defmodule Uppy.Testing do
  def reverse_id(id) do
    id |> Integer.to_string() |> String.reverse()
  end
end
