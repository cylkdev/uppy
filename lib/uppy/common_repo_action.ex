defmodule Uppy.CommonRepoAction do
  @moduledoc false

  alias Uppy.Config

  @behaviour Uppy.DBAction

  @repo Uppy.Repo

  @doc """
  ...
  """
  @impl true
  def transaction(func, opts) do
    opts = Keyword.merge(default_opts(opts), opts)

    opts[:repo].transaction(func, opts)
  end

  @doc """
  ...
  """
  @impl true
  def preload(struct_or_structs, preloads, opts) do
    opts = Keyword.merge(default_opts(opts), opts)

    opts[:repo].preload(struct_or_structs, preloads, opts)
  end

  @doc """
  ...
  """
  @impl true
  def update_all(query, params, updates, opts) do
    opts = Keyword.merge(default_opts(opts), opts)

    query
    |> EctoShorts.CommonFilters.convert_params_to_filter(params)
    |> opts[:repo].update_all(updates, opts)
  end

  @doc """
  ...
  """
  @impl true
  def aggregate(query, params \\ %{}, aggregate \\ :count, field \\ :id, opts) do
    opts = Keyword.merge(default_opts(opts), opts)

    query
    |> EctoShorts.CommonFilters.convert_params_to_filter(params)
    |> opts[:repo].aggregate(aggregate, field, opts)
  end

  @doc """
  ...
  """
  @impl true
  def all(query, opts) do
    opts = Keyword.merge(default_opts(opts), opts)

    EctoShorts.Actions.all(query, opts)
  end

  @doc """
  ...
  """
  @impl true
  def all(query, params, opts) do
    opts = Keyword.merge(default_opts(opts), opts)

    EctoShorts.Actions.all(query, params, opts)
  end

  @doc """
  ...
  """
  @impl true
  def create(query, params, opts) do
    opts = Keyword.merge(default_opts(opts), opts)

    EctoShorts.Actions.create(query, params, opts)
  end

  @doc """
  ...
  """
  @impl true
  def find(query, params, opts) do
    opts = Keyword.merge(default_opts(opts), opts)

    EctoShorts.Actions.find(query, params, opts)
  end

  @doc """
  ...
  """
  @impl true
  def update(query, id_or_struct, params, opts) do
    opts = Keyword.merge(default_opts(opts), opts)

    EctoShorts.Actions.update(query, id_or_struct, params, opts)
  end

  @doc """
  ...
  """
  @impl true
  def delete(struct, opts) do
    opts = Keyword.merge(default_opts(opts), opts)

    EctoShorts.Actions.delete(struct, opts)
  end

  @doc """
  ...
  """
  @impl true
  def delete(query, id_or_params, opts) do
    opts = Keyword.merge(default_opts(opts), opts)

    EctoShorts.Actions.delete(query, id_or_params, opts)
  end

  defp default_opts(opts) do
    [repo: repo!(opts)]
  end

  defp repo!(opts) do
    opts[:repo] || Config.repo() || @repo
  end
end
