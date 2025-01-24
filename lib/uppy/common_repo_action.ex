defmodule Uppy.CommonRepoAction do
  @moduledoc false

  alias Uppy.Config

  @behaviour Uppy.DBAction

  @repo Uppy.Repo

  def transaction(func, opts \\ []) do
    opts = Keyword.merge(default_opts(opts), opts)

    opts[:repo].transaction(func, opts)
  end

  def preload(struct_or_structs, preloads, opts \\ []) do
    opts = Keyword.merge(default_opts(opts), opts)

    opts[:repo].preload(struct_or_structs, preloads, opts)
  end

  def update_all(query, params, updates, opts) do
    opts = Keyword.merge(default_opts(opts), opts)

    query
    |> EctoShorts.CommonFilters.convert_params_to_filter(params)
    |> opts[:repo].update_all(updates, opts)
  end

  def aggregate(query, params \\ %{}, aggregate \\ :count, field \\ :id, opts \\ []) do
    opts = Keyword.merge(default_opts(opts), opts)

    query
    |> EctoShorts.CommonFilters.convert_params_to_filter(params)
    |> opts[:repo].aggregate(aggregate, field, opts)
  end

  def all(query) do
    all(query, default_opts([]))
  end

  def all(query, opts) do
    opts = Keyword.merge(default_opts(opts), opts)

    EctoShorts.Actions.all(query, opts)
  end

  def all(query, params, opts) do
    opts = Keyword.merge(default_opts(opts), opts)

    EctoShorts.Actions.all(query, params, opts)
  end

  def create(query, params, opts \\ []) do
    opts = Keyword.merge(default_opts(opts), opts)

    EctoShorts.Actions.create(query, params, opts)
  end

  def find(query, params, opts \\ []) do
    opts = Keyword.merge(default_opts(opts), opts)

    EctoShorts.Actions.find(query, params, opts)
  end

  def update(query, id_or_struct, params, opts \\ []) do
    opts = Keyword.merge(default_opts(opts), opts)

    EctoShorts.Actions.update(query, id_or_struct, params, opts)
  end

  def delete(struct, opts \\ [])

  def delete(struct, opts) do
    opts = Keyword.merge(default_opts(opts), opts)

    EctoShorts.Actions.delete(struct, opts)
  end

  def delete(query, id_or_params, opts) do
    opts = Keyword.merge(default_opts(opts), opts)

    EctoShorts.Actions.delete(query, id_or_params, opts)
  end

  defp default_opts(opts) do
    [repo: repo!(opts)]
  end

  defp repo!(opts) do
    with nil <- opts[:repo],
         nil <- Config.repo() do
      @repo
    end
  end
end
