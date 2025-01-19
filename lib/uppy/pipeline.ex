defmodule Uppy.Pipeline do
  @moduledoc """
  A pipeline is a list of phases.

  Phases are executed sequentially, with the output of
  one phase serving as the input to the next.

  Pipelines are used to perform operations on objects
  existing in storage.

    * See `Uppy.Phase` for information on building a phase.
  """
  alias Uppy.Phase

  def run(input, pipeline) do
    pipeline
    |> List.flatten()
    |> run_phase(input, [])
  end

  def run_phase(pipeline, input, done)

  def run_phase([], input, done) do
    {:ok, input, done}
  end

  def run_phase([phase | todo] = _all_phases, input, done) do
    {phase, opts} = phase_config(phase)

    case Phase.run(phase, input, opts) do
      {:ok, result} ->
        run_phase(todo, result, [phase | done])

      {:error, message} ->
        {:error, {message, [phase | done]}}

      term ->
        raise """
        Expected one of:

        `{:ok, result}`
        `{:error, message}`

        got:

        #{inspect(term, pretty: true)}
        """
    end
  end

  def run_phase(phase, input, done) do
    run_phase([phase], input, done)
  end

  defp phase_config({phase, opts}) when is_atom(phase) and is_list(opts), do: {phase, opts}
  defp phase_config(phase), do: phase_config({phase, []})
end
