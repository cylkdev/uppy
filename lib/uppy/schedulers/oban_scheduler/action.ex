defmodule Uppy.Schedulers.ObanScheduler.Action do
  @moduledoc false

  alias Uppy.Schedulers.ObanScheduler

  @doc """
  ...
  """
  @callback insert(Ecto.Changeset.t(Oban.Job.t()), keyword()) :: {:ok, term()} | {:error, term()}

  @doc """
  ...
  """
  @callback insert(module(), map(), keyword()) :: {:ok, term()} | {:error, term()}

  @doc """
  ...
  """
  def insert(changeset, opts) do
    adapter!(opts).insert(changeset, opts)
  end

  @doc """
  ...
  """
  def insert(worker, params, opts) do
    adapter!(opts).insert(worker, params, opts)
  end

  defp adapter!(opts) do
    opts[:oban_action_adapter] ||
      ObanScheduler.Config.scheduler()[:oban_action_adapter] ||
      Uppy.Schedulers.ObanScheduler.CommonAction
  end
end
