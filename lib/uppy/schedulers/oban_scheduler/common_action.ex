defmodule Uppy.Schedulers.ObanScheduler.CommonAction do
  @moduledoc """
  ...
  """

  def query_to_args({source, query}), do: %{source: source, query: to_string(query)}
  def query_to_args(query), do: %{query: to_string(query)}

  def get_args_query(%{"source" => source, "query" => query}),
    do: {source, string_to_module(query)}

  def get_args_query(%{"query" => query}), do: string_to_module(query)

  defp string_to_module(string), do: string |> String.split(".") |> Module.safe_concat()

  def insert(changeset, opts) do
    opts
    |> oban_name!()
    |> Oban.insert(changeset, opts)
  end

  def insert(worker, params, opts) do
    worker
    |> build_changeset(params, opts)
    |> insert(opts)
  end

  defp build_changeset(worker, params, opts) do
    if Keyword.has_key?(opts, :worker) do
      Oban.Job.new(params, Keyword.take(opts, []))
    else
      worker.new(params, Keyword.take(opts, []))
    end
  end

  defp oban_name!(opts) do
    with nil <- opts[:oban_name],
         nil <- Uppy.Config.oban_name() do
      Oban
    end
  end
end
