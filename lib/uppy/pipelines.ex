defmodule Uppy.Pipelines do
  @moduledoc false

  def pipeline_for(:move_to_destination, opts) do
    [{Uppy.Phases.MoveToDestination, opts}]
  end
end
