defmodule Uppy.Schedulers.ObanScheduler.Actions.CommonAction do
  @moduledoc """
  ...
  """

  @config Application.compile_env(Uppy.Config.app(), Oban, [])

  @doc false
  def __config__, do: @config

  def insert(changeset, opts) do
    Oban.insert(oban_name!(), changeset, opts)
  end

  def insert(worker, params, opts) do
    worker
    |> build_changeset(params, opts)
    |> insert(opts)
  end

  defp build_changeset(worker, params, opts) do
    if Keyword.has_key?(opts, :worker) do
      Oban.Job.new(params, opts)
    else
      worker.new(params, opts)
    end
  end

  defp oban_name! do
    @config[:name] || Uppy.Oban
  end
end
