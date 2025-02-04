defmodule Uppy.Core.Pipelines do
  @moduledoc false

  def for_move_to_destination(opts) do
    [{Uppy.Phases.MoveToDestination, opts}]
  end
end
