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
  @type phase_response :: {:ok, term()} | {:error, term()}

  @callback run(input :: input(), opts :: opts()) :: term()

  @doc """
  Executes the callback function `c:Uppy.Phase.run/2`.

  Raises if the phase does not define the function `run/2`.

  ### Examples

      iex> defmodule EchoPhase do
      ...>   @behaviour Uppy.Phase
      ...>
      ...>   @impl true
      ...>   def run(input, opts), do: {:ok, %{input: input, opts: opts}}
      ...> end
      ...> Uppy.Phase.run(EchoPhase, %{likes: 10})
      {:ok, %{input: %{likes: 10}, opts: []}}
  """
  @spec run(
    phase :: phase(),
    input :: input(),
    opts :: opts()
  ) :: term()
  def run(phase, input, opts \\ []) do
    phase.run(input, opts)
  end
end
