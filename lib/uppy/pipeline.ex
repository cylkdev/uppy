defmodule Uppy.Pipeline do
  alias Uppy.Phase

  def pipeline(adapter) do
    case adapter.pipeline() do
      phases when is_list(phases) ->
        phases

      term ->
        "Expected module `#{inspect(adapter)}` to return a list of phases, got: #{inspect(term, pretty: true)}"
    end
  end

  def run(%Uppy.Pipeline.Input{} = input, pipeline) do
    pipeline
    |> List.flatten()
    |> run_phase(input)
  end

  def run_phase(pipeline, input, done \\ [])

  def run_phase([], input, done) do
    {:ok, input, done}
  end

  def run_phase([phase | todo] = _phases, input, done) do
    {phase, opts} = phase_config(phase)

    case Phase.run(phase, input, opts) do
      {:ok, output} ->
        run_phase(todo, output, [phase | done])

      {:error, message} ->
        {:error, {message, [phase | done]}}

      term ->
        raise """
        Expected one of:

        {:ok, term()}
        {:error, String.t()}

        got:

        #{inspect(term, pretty: true)}
        """
    end
  end

  defp phase_config({phase, opts}) when is_atom(phase) and is_list(opts), do: {phase, opts}
  defp phase_config(phase), do: phase_config({phase, []})
end
