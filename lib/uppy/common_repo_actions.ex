defmodule Uppy.CommonRepoActions do
  @moduledoc false

  @behaviour Uppy.DBAction

  @repo Uppy.Support.Repo

  @doc """
  ...
  """
  @impl true
  def transaction(fun, opts) do
    opts = Keyword.merge(default_opts(), opts)

    repo(opts).transaction(
      fn repo ->
        case if is_function(fun, 1), do: fun.(repo), else: fun.() do
          {:error, e} -> repo.rollback(e)
          {:ok, _} = res -> res
          term -> raise "Expected {:ok, term()} or {:error, term()}, got: #{inspect(term)}"
        end
      end,
      opts
    )
  end

  @doc """
  ...
  """
  @impl true
  def update_all(query, params, updates, opts) do
    opts = Keyword.merge(default_opts(), opts)

    query
    |> EctoShorts.CommonFilters.convert_params_to_filter(params)
    |> repo(opts).update_all(updates, opts)
  end

  @doc """
  ...
  """
  @impl true
  def aggregate(query, params \\ %{}, aggregate \\ :count, field \\ :id, opts \\ []) do
    opts = Keyword.merge(default_opts(), opts)

    query
    |> EctoShorts.CommonFilters.convert_params_to_filter(params)
    |> repo(opts).aggregate(aggregate, field, opts)
  end

  @doc """
  ...
  """
  @impl true
  def all(query, opts) do
    opts = Keyword.merge(default_opts(), opts)

    EctoShorts.Actions.all(query, opts)
  end

  @doc """
  ...
  """
  @impl true
  def all(query, params, opts) do
    opts = Keyword.merge(default_opts(), opts)

    EctoShorts.Actions.all(query, params, opts)
  end

  @doc """
  ...
  """
  @impl true
  def create(query, params, opts) do
    opts = Keyword.merge(default_opts(), opts)

    EctoShorts.Actions.create(query, params, opts)
  end

  @doc """
  ...
  """
  @impl true
  def find(query, params, opts) do
    opts = Keyword.merge(default_opts(), opts)

    EctoShorts.Actions.find(query, params, opts)
  end

  @doc """
  ...
  """
  @impl true
  def update(query, id_or_struct, params, opts) do
    opts = Keyword.merge(default_opts(), opts)

    EctoShorts.Actions.update(query, id_or_struct, params, opts)
  end

  @doc """
  ...
  """
  @impl true
  def delete(struct, opts) do
    opts = Keyword.merge(default_opts(), opts)

    EctoShorts.Actions.delete(struct, opts)
  end

  @doc """
  ...
  """
  @impl true
  def delete(query, id_or_params, opts) do
    opts = Keyword.merge(default_opts(), opts)

    EctoShorts.Actions.delete(query, id_or_params, opts)
  end

  defp default_opts do
    [repo: EctoShorts.Config.repo() || @repo]
  end

  defp repo(opts) do
    opts[:repo] || EctoShorts.Config.repo() || @repo
  end
end
