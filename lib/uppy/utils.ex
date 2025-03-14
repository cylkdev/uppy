defmodule Uppy.Utils do
  @moduledoc false

  def deep_keyword_merge(kwd1, kwd2) do
    Keyword.merge(kwd1, kwd2, fn
      _key, v1, v2 when is_list(v1) ->
        if Keyword.keyword?(v1) do
          deep_keyword_merge(v1, v2)
        else
          v2
        end

      _key, _v1, v2 ->
        v2
    end)
  end

  def process_alive?(name) do
    case Process.whereis(name) do
      nil -> false
      pid -> Process.alive?(pid)
    end
  end

  def drop_nil_values(enum) do
    Enum.reject(enum, fn {_, v} -> is_nil(v) end)
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
