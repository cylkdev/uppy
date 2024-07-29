defmodule Uppy.Pipeline do
  alias Uppy.Phase

  def for_post_processing(_options \\ []) do
    [
      Uppy.Phases.TemporaryObjectKeyValidate,
      Uppy.Phases.Holder,
      Uppy.Phases.HeadTemporaryObject,
      Uppy.Phases.FileInfo,
      Uppy.Phases.PutPermanentThumborResult,
      Uppy.Phases.PutPermanentObjectCopy,
      Uppy.Phases.UpdateSchemaMetadata,
      Uppy.Phases.PermanentObjectKeyValidate
    ]
  end

  def run(%Uppy.Pipeline.Input{} = input, pipeline) do
    pipeline
    |> List.flatten()
    |> run_phase(input)
  end

  @doc """
  Return the part of a pipeline before a specific phase.

  ## Examples

      iex> Pipeline.before([A, B, C], B)
      [A]
  """
  def before(pipeline, phase) do
    result =
      List.flatten(pipeline)
      |> Enum.take_while(&(!match_phase?(phase, &1)))

    case result do
      ^pipeline ->
        raise RuntimeError, "Could not find phase #{phase}"

      _ ->
        result
    end
  end

  @doc """
  Return the part of a pipeline after (and including) a specific phase.

  ## Examples

      iex> Pipeline.from([A, B, C], B)
      [B, C]
  """
  def from(pipeline, phase) do
    result =
      List.flatten(pipeline)
      |> Enum.drop_while(&(!match_phase?(phase, &1)))

    case result do
      [] ->
        raise RuntimeError, "Could not find phase #{phase}"

      _ ->
        result
    end
  end

  @doc """
  Replace a phase in a pipeline with another, supporting reusing the same
  options.

  ## Examples

  Replace a simple phase (without options):

      iex> Pipeline.replace([A, B, C], B, X)
      [A, X, C]

  Replace a phase with options, retaining them:

      iex> Pipeline.replace([A, {B, [name: "Thing"]}, C], B, X)
      [A, {X, [name: "Thing"]}, C]

  Replace a phase with options, overriding them:

      iex> Pipeline.replace([A, {B, [name: "Thing"]}, C], B, {X, [name: "Nope"]})
      [A, {X, [name: "Nope"]}, C]

  """
  def replace(pipeline, phase, replacement) do
    Enum.map(pipeline, fn candidate ->
      case match_phase?(phase, candidate) do
        true ->
          case phase_invocation(candidate) do
            {_, []} ->
              replacement

            {_, options} ->
              if is_atom(replacement) do
                {replacement, options}
              else
                replacement
              end
          end

        false ->
          candidate
      end
    end)
  end

  defp phase_invocation({phase, options}) when is_list(options) do
    {phase, options}
  end

  defp phase_invocation(phase) do
    {phase, []}
  end

  defp match_phase?(phase, phase), do: true
  defp match_phase?(phase, {phase, _}) when is_atom(phase), do: true
  defp match_phase?(_, _), do: false

  @doc """
  Return the part of a pipeline up to and including a specific phase.

  ## Examples

      iex> Pipeline.upto([A, B, C], B)
      [A, B]
  """
  def upto(pipeline, phase) do
    beginning = before(pipeline, phase)
    item = get_in(pipeline, [Access.at(length(beginning))])
    beginning ++ [item]
  end

  @doc """
  Return the pipeline with the supplied phase removed.

  ## Examples

      iex> Pipeline.without([A, B, C], B)
      [A, C]
  """
  def without(pipeline, phase) do
    pipeline
    |> Enum.filter(&(not match_phase?(phase, &1)))
  end

  @doc """
  Return the pipeline with the phase/list of phases inserted before
  the supplied phase.

  ## Examples

  Add one phase before another:

      iex> Pipeline.insert_before([A, C, D], C, B)
      [A, B, C, D]

  Add list of phase before another:

      iex> Pipeline.insert_before([A, D, E], D, [B, C])
      [A, B, C, D, E]

  """
  def insert_before(pipeline, phase, additional) do
    beginning = before(pipeline, phase)
    beginning ++ List.wrap(additional) ++ (pipeline -- beginning)
  end

  @doc """
  Return the pipeline with the phase/list of phases inserted after
  the supplied phase.

  ## Examples

  Add one phase after another:

      iex> Pipeline.insert_after([A, C, D], A, B)
      [A, B, C, D]

  Add list of phases after another:

      iex> Pipeline.insert_after([A, D, E], A, [B, C])
      [A, B, C, D, E]

  """
  def insert_after(pipeline, phase, additional) do
    beginning = upto(pipeline, phase)
    beginning ++ List.wrap(additional) ++ (pipeline -- beginning)
  end

  @doc """
  Return the pipeline with the phases matching the regex removed.

  ## Examples

      iex> Pipeline.reject([A, B, C], ~r/A|B/)
      [C]
  """
  def reject(pipeline, %Regex{} = pattern) do
    reject(pipeline, fn phase ->
      Regex.match?(pattern, Atom.to_string(phase))
    end)
  end

  def reject(pipeline, fun) do
    Enum.reject(pipeline, fn
      {phase, _} -> fun.(phase)
      phase -> fun.(phase)
    end)
  end

  def run_phase(pipeline, input, done \\ [])

  def run_phase([], input, done) do
    {:ok, input, done}
  end

  def run_phase([phase | todo] = all_phases, input, done) do
    {phase, options} = phase_config(phase)

    case Phase.run(phase, input, options) do
      {:record_phases, result, fun} ->
        result = fun.(result, all_phases)
        run_phase(todo, result, [phase | done])

      {:ok, result} ->
        run_phase(todo, result, [phase | done])

      {:jump, result, destination_phase} when is_atom(destination_phase) ->
        run_phase(from(todo, destination_phase), result, [phase | done])

      {:insert, result, extra_pipeline} ->
        run_phase(List.wrap(extra_pipeline) ++ todo, result, [phase | done])

      {:swap, result, target, replacements} ->
        todo
        |> replace(target, replacements)
        |> run_phase(result, [phase | done])

      {:replace, result, final_pipeline} ->
        run_phase(List.wrap(final_pipeline), result, [phase | done])

      {:error, message} ->
        {:error, {message, [phase | done]}}

      term ->
        raise """
        Expected one of:

        `{:record_phases, result, fun}`
        `{:ok, result}`
        `{:jump, result, destination_phase}`
        `{:insert, result, extra_pipeline}`
        `{:swap, result, target, replacements}`
        `{:replace, result, final_pipeline}`
        `{:error, message}`

        got:

        #{inspect(term, pretty: true)}
        """
    end
  end

  defp phase_config({phase, options}) when is_atom(phase) and is_list(options), do: {phase, options}
  defp phase_config(phase), do: phase_config({phase, []})
end
