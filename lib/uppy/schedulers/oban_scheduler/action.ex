defmodule Uppy.Schedulers.ObanScheduler.Action do
  @moduledoc false

  @config Application.compile_env(Uppy.Config.app(), __MODULE__, [])

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
      @config[:oban_action_adapter] ||
      Uppy.Schedulers.ObanScheduler.Actions.CommonAction
  end
end
