defmodule Uppy.Phase do
  @moduledoc """
  A phase represents a distinct step in a pipeline.

  A phase is responsible for a specific task. The output
  of one phase serves as the input for the next phase.

  See `Uppy.Adapter.Phase` for information on building a phase.
  """

  @type phase :: Uppy.Adapter.Phase.t()

  @type input :: Uppy.Adapter.Phase.input()

  @type options :: Uppy.Adapter.Phase.options()

  @doc """
  Executes the callback function `c:Uppy.Adapter.Phase.run/2`.

  Raises if the phase does not define the function `run/2`.

  ### Examples

      iex> defmodule EchoPhase do
      ...>   @behaviour Uppy.Adapter.Phase
      ...>
      ...>   @impl true
      ...>   def run(input, opts), do: {:ok, %{input: input, options: opts}}
      ...> end
      ...> Uppy.Phase.run(EchoPhase, %{likes: 10})
      {:ok, %{input: %{likes: 10}, options: []}}
  """
  @spec run(
    phase :: phase(),
    input :: input(),
    options :: options()
  ) :: term()
  def run(phase, input, options \\ []) do
    phase.run(input, options)
  end
end
