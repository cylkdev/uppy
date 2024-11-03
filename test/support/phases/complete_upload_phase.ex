defmodule Uppy.Phases.CompleteUploadPhase do
  @moduledoc false

  @behaviour Uppy.Phase

  @impl true
  def phase_completed?(_), do: false

  @impl true
  def run(resolution, _opts \\ []), do: {:ok, resolution}
end
