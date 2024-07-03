defmodule Uppy.Adapters.Scheduler.Oban.Config do
  @moduledoc false

  @spec name :: atom() | Oban
  def name, do: Keyword.get(get_env(), :name, Oban)

  @spec get_env :: Keyword.t()
  def get_env, do: Application.get_env(Uppy.Config.app(), Oban, [])
end
