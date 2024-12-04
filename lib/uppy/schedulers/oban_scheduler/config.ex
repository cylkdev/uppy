defmodule Uppy.Schedulers.ObanScheduler.Config do
  @moduledoc """
  ...
  """


  def oban do
    Application.get_env(Uppy.Config.app(), Oban) || []
  end

  def scheduler do
    Application.get_env(Uppy.Config.app(), :oban_scheduler) || []
  end
end
