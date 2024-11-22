defmodule Uppy.Schedulers.ObanScheduler.CommonAction do
  @moduledoc """
  ...
  """

  alias Uppy.Schedulers.ObanScheduler

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
      Oban.Job.new(params, opts)
    else
      worker.new(params, opts)
    end
  end

  defp oban_name!(opts) do
    with nil <- opts[:oban][:name] || ObanScheduler.Config.oban()[:name] do
      raise ArgumentError, "Oban not configured."
    end
  end
end
