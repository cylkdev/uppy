defmodule Uppy.Pipeline.Phase do
  def run(phase, input, options) do
    phase.run(input, options)
  end
end

defmodule Uppy.Pipeline do
  alias Uppy.Pipeline.Phase

  def run(input, pipeline) do
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
      {:ok, result} ->
        run_phase(todo, result, [phase | done])

      {:error, message} ->
        {:error, message, [phase | done]}

      term ->
        raise ArgumentError,
              """
              Expected one of:

              - `{:ok, result}`
              - `{:error, message}`

              got:

              #{inspect(term, pretty: true)}
              """
    end
  end

  defp phase_config({phase, opts}) when is_atom(phase) and is_list(opts), do: {phase, opts}
  defp phase_config(phase), do: phase_config({phase, []})
end
