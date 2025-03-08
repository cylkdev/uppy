defmodule Uppy.Utils do
  @moduledoc false

  def normalize_process_name(term, suffix \\ "") do
    str = to_string(term)

    if String.contains?(str, ".") do
      str
      |> String.replace("Elixir.", "")
      |> String.split(".", trim: true)
      |> List.last()
      |> Macro.underscore()
      |> String.trim_trailing(suffix)
    else
      str
      |> Macro.underscore()
      |> String.trim_trailing(suffix)
    end
  end

  @doc """
  Converts a string to an atom.

  ### Examples

      iex> Uppy.Utils.string_to_module("Elixir.Enum")
      Enum
  """
  @spec string_to_module(String.t()) :: module()
  def string_to_module(string) do
    string
    |> String.split(".", trim: true)
    |> Module.concat()
  end

  @doc """
  Converts a string to an existing module atom.

  ### Examples

      iex> Uppy.Utils.string_to_existing_module("Elixir.Enum")
      Enum
  """
  @spec string_to_existing_module(String.t()) :: module()
  def string_to_existing_module(string) do
    string
    |> String.split(".", trim: true)
    |> Module.safe_concat()
  end

  @doc """
  Returns true if all modules are loaded

  ### Examples

      iex> Uppy.Utils.ensure_all_loaded?([Enum])
      true
  """
  @spec ensure_all_loaded?(list()) :: boolean()
  def ensure_all_loaded?(modules) do
    Enum.all?(modules, &Code.ensure_loaded?/1)
  end

  @doc """
  Converts all string keys to atoms

  ### Example

      iex> Uppy.Utils.atomize_keys(%{"test" => 5, hello: 4})
      %{test: 5, hello: 4}

      iex> Uppy.Utils.atomize_keys([%{"a" => 5}, %{b: 2}])
      [%{a: 5}, %{b: 2}]
  """
  @spec atomize_keys(Enum.t()) :: Enum.t()
  def atomize_keys(map) do
    transform_keys(map, fn
      key when is_binary(key) -> String.to_atom(key)
      key -> key
    end)
  end

  defp transform_keys(map, transform_fn) do
    deep_transform(map, fn {k, v} -> {transform_fn.(k), v} end)
  end

  @doc """
  Deeply transform key value pairs from maps to apply operations on nested maps

  ### Example

      iex> Uppy.Utils.deep_transform(%{"test" => %{"item" => 2, "d" => 3}}, fn {k, v} ->
      ...>   if k === "d" do
      ...>     :delete
      ...>   else
      ...>     {String.to_atom(k), v}
      ...>   end
      ...> end)
      %{test: %{item: 2}}
  """
  @spec deep_transform(map, fun) :: map
  @spec deep_transform(list, fun) :: list
  def deep_transform(map, transform_fn) when is_map(map) do
    Enum.reduce(map, %{}, fn {k, v}, acc ->
      case transform_fn.({k, v}) do
        {k, v} -> Map.put(acc, k, deep_transform(v, transform_fn))
        :delete -> acc
      end
    end)
  end

  def deep_transform(list, transform_fn) when is_list(list) do
    Enum.map(list, &deep_transform(&1, transform_fn))
  end

  def deep_transform(value, _), do: value
end
