defmodule Uppy.Phase do
  @moduledoc """
  A phase represents a distinct step in a pipeline.

  A phase is responsible for a specific task. The output
  of one phase serves as the input for the next phase.

  See `Uppy.Phase` for information on building a phase.
  """

  @type input :: term()
  @type opts :: keyword()
  @type phase :: module() | {module(), opts()}

  @callback run(input :: input(), opts :: opts()) :: term()

  @doc """
  Executes the callback function `c:Uppy.Phase.run/2`.

  Raises if the phase does not define the function `run/2`.
  """
  @spec run(
    phase :: phase(),
    input :: input(),
    opts :: opts()
  ) :: {:ok, term()} | {:error, term()}
  def run(phase, input, opts) do
    phase.run(input, opts)
  end
end
