defmodule Uppy.Schedulers.ObanScheduler.CommonAction do
  @moduledoc """
  ...
  """

  def random_minutes do
    Enum.random(:timer.minutes(30)..:timer.minutes(60))
  end

  def query_to_args({source, query}), do: %{source: source, query: to_string(query)}
  def query_to_args(query), do: %{query: to_string(query)}

  def get_args_query(%{"source" => source, "query" => query}),
    do: {source, string_to_module(query)}

  def get_args_query(%{"query" => query}), do: string_to_module(query)

  defp string_to_module(string), do: string |> String.split(".") |> Module.safe_concat()

  def insert(changeset, schedule_in_or_at, opts) do
    opts
    |> oban_name!()
    |> Oban.insert(changeset, put_schedule_opts(opts, schedule_in_or_at))
  end

  defp put_schedule_opts(opts, schedule_in) when is_integer(schedule_in) do
    Keyword.put(opts, :schedule_in, schedule_in)
  end

  defp put_schedule_opts(opts, schedule_at) when is_struct(schedule_at, DateTime) do
    Keyword.put(opts, :schedule_at, schedule_at)
  end

  defp put_schedule_opts(opts, _) do
    opts
  end

  def insert(worker, params, schedule_in_or_at, opts) do
    worker
    |> build_changeset(params, opts)
    |> insert(schedule_in_or_at, opts)
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
      :uppy_oban
    end
  end
end
