defmodule Uppy.Support.Phases.EchoPhase do
  @moduledoc false

  @behaviour Uppy.Adapter.Phase

  @doc false
  @impl true
  def run(input, opts) do
    {:ok, %{input: input, options: opts}}
  end
end
