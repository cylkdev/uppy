defmodule Uppy.Pipeline do
  @moduledoc """
  A pipeline is a list of phases.

  Phases are executed sequentially, with the output of
  one phase serving as the input to the next.

  Pipelines are used to perform operations on objects
  existing in storage.

    * See `Uppy.Adapter.Phase` for information on building a phase.
  """
  alias Uppy.Phase

  @type phase :: Uppy.Phase.phase()

  @type input :: Uppy.Phase.input()

  @type options :: Uppy.options()

  @type error_message :: Uppy.Error.error_message()

  @type phases :: list(phase())

  @type pipeline :: phases()

  @type pipeline_response ::
    {:ok, result :: result(), done :: phases()} |
    {:error, error_message :: error_message(), done :: phases()}

  @type result :: term()

  @doc """
  Returns the list of phases for processing completed file uploads.

  ### Examples

      iex> Uppy.Pipeline.for_post_processing()
      [
        {Uppy.Phases.ValidateObjectTemporaryPath, []},
        {Uppy.Phases.HeadTemporaryObject, []},
        {Uppy.Phases.FileHolder, []},
        {Uppy.Phases.FileInfo, []},
        {Uppy.Phases.PutImageProcessorResult, []},
        {Uppy.Phases.PutPermanentObjectCopy, []},
        {Uppy.Phases.UpdateSchemaMetadata, []},
        {Uppy.Phases.ValidateObjectPermanentPath, []}
      ]
  """
  @spec for_post_processing(options :: options()) :: phases()
  def for_post_processing(opts \\ []) do
    [
      {Uppy.Phases.ValidateObjectTemporaryPath, opts},
      {Uppy.Phases.HeadTemporaryObject, opts},
      {Uppy.Phases.FileHolder, opts},
      {Uppy.Phases.FileInfo, opts},
      {Uppy.Phases.PutImageProcessorResult, opts},
      {Uppy.Phases.PutPermanentObjectCopy, opts},
      {Uppy.Phases.ValidateObjectPermanentPath, opts},
      {Uppy.Phases.UpdateSchemaMetadata, opts}
    ]
  end

  @doc """
  Flattens a list of phases and executes each phase
  sequentially.

  ### Examples

      iex> Uppy.Pipeline.run("input", [Uppy.Support.Phases.EchoPhase])
      {:ok, %{input: "input", options: []}, [Uppy.Support.Phases.EchoPhase]}

      iex> Uppy.Pipeline.run("input", [{Uppy.Support.Phases.EchoPhase, resource: "resource"}])
      {:ok, %{input: "input", options: [resource: "resource"]}, [Uppy.Support.Phases.EchoPhase]}
  """
  @spec run(input :: input(), pipeline :: phases()) :: pipeline_response()
  def run(input, pipeline) do
    pipeline
    |> List.flatten()
    |> run_phase(input)
  end

  @doc """
  Return the part of a pipeline before a specific phase.

  ## Examples

      iex> Uppy.Pipeline.before([A, B, C], B)
      [A]
  """
  @spec before(pipeline :: phases(), phase :: phase()) :: phases()
  def before(pipeline, phase) do
    result =
      pipeline
      |> List.flatten()
      |> Enum.take_while(fn existing_phase ->
        match_phase?(phase, existing_phase) === false
      end)

    case result do
      ^pipeline -> raise RuntimeError, "Phase #{inspect(phase)} not found."
      _ -> result
    end
  end

  @doc """
  Return the part of a pipeline after (and including) a specific phase.

  ## Examples

      iex> Uppy.Pipeline.from([A, B, C], B)
      [B, C]
  """
  @spec from(pipeline :: phases(), phase :: phase()) :: phases()
  def from(pipeline, phase) do
    result =
      pipeline
      |> List.flatten()
      |> Enum.drop_while(fn existing_phase ->
        match_phase?(phase, existing_phase) === false
      end)

    case result do
      [] -> raise RuntimeError, "Phase #{inspect(phase)} not found."
      _ -> result
    end
  end

  @doc """
  Replace a phase in a pipeline with another, supporting reusing the same
  options.

  ## Examples

  Replace a simple phase (without options):

      iex> Uppy.Pipeline.replace([A, B, C], B, X)
      [A, X, C]

  Replace a phase with options, retaining them:

      iex> Uppy.Pipeline.replace([A, {B, [name: "Thing"]}, C], B, X)
      [A, {X, [name: "Thing"]}, C]

  Replace a phase with options, overriding them:

      iex> Uppy.Pipeline.replace([A, {B, [name: "Thing"]}, C], B, {X, [name: "Nope"]})
      [A, {X, [name: "Nope"]}, C]

  """
  @spec replace(
    pipeline :: phases(),
    phase :: phase(),
    replacement :: phase()
  ) :: phases()
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

      iex> Uppy.Pipeline.upto([A, B, C], B)
      [A, B]
  """
  @spec upto(pipeline :: phases(), phase :: phase()) :: phases()
  def upto(pipeline, phase) do
    beginning = before(pipeline, phase)

    item = get_in(pipeline, [Access.at(length(beginning))])

    beginning ++ [item]
  end

  @doc """
  Return the pipeline with the supplied phase removed.

  ## Examples

      iex> Uppy.Pipeline.without([A, B, C], B)
      [A, C]
  """
  @spec without(pipeline :: phases(), phase :: phase()) :: phases()
  def without(pipeline, phase) do
    Enum.filter(pipeline, fn existing_phase ->
      match_phase?(phase, existing_phase) === false
    end)
  end

  @doc """
  Return the pipeline with the phase/list of phases inserted before
  the supplied phase.

  ## Examples

  Add one phase before another:

      iex> Uppy.Pipeline.insert_before([A, C, D], C, B)
      [A, B, C, D]

  Add list of phase before another:

      iex> Uppy.Pipeline.insert_before([A, D, E], D, [B, C])
      [A, B, C, D, E]

  """
  @spec insert_before(
    pipeline :: phases(),
    phase :: phase(),
    additional :: phases()
  ) :: phases()
  def insert_before(pipeline, phase, additional) do
    beginning = before(pipeline, phase)

    beginning ++ List.wrap(additional) ++ (pipeline -- beginning)
  end

  @doc """
  Return the pipeline with the phase/list of phases inserted after
  the supplied phase.

  ## Examples

  Add one phase after another:

      iex> Uppy.Pipeline.insert_after([A, C, D], A, B)
      [A, B, C, D]

  Add list of phases after another:

      iex> Uppy.Pipeline.insert_after([A, D, E], A, [B, C])
      [A, B, C, D, E]

  """
  @spec insert_after(
    pipeline :: phases(),
    phase :: phase(),
    additional :: phases()
  ) :: phases()
  def insert_after(pipeline, phase, additional) do
    beginning = upto(pipeline, phase)

    beginning ++ List.wrap(additional) ++ (pipeline -- beginning)
  end

  @doc """
  Return the pipeline with the phases matching the regex removed.

  ## Examples

      iex> Uppy.Pipeline.reject([A, B, C], ~r/A|B/)
      [C]
  """
  @spec reject(
    pipeline :: phases(),
    pattern_or_function :: Regex.t() | function()
  ) :: phases()
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

  @doc """
  Executes phases with the given input.

  ### Examples
      iex> Uppy.Pipeline.run_phase([Uppy.Support.Phases.EchoPhase], %{likes: 10})
      {:ok, %{input: %{likes: 10}, options: []}, [Uppy.Support.Phases.EchoPhase]}
  """
  @spec run_phase(
    phase :: phase() | phases(),
    input :: input(),
    done :: phases()
  ) :: pipeline_response()
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
        todo
        |> from(destination_phase)
        |> run_phase(result, [phase | done])

      {:insert, result, extra_pipeline} ->
        extra_pipeline
        |> List.wrap()
        |> Kernel.++(todo)
        |> run_phase(result, [phase | done])

      {:swap, result, target, replacements} ->
        todo
        |> replace(target, replacements)
        |> run_phase(result, [phase | done])

      {:replace, result, final_pipeline} ->
        final_pipeline
        |> List.wrap()
        |> run_phase(result, [phase | done])

      {:error, message} ->
        {:error, {message, [phase | done]}}

      term ->
        raise """
        Expected one of:

        `{:record_phases, result, function}`
        `{:ok, result}`
        `{:jump, result, destination_phase}`
        `{:insert, result, extra_pipeline}`
        `{:swap, result, target, replacements}`
        `{:replace, result, phases}`
        `{:error, message}`

        got:

        #{inspect(term, pretty: true)}
        """
    end
  end

  def run_phase(phase, input, done) do
    run_phase([phase], input, done)
  end

  defp phase_config({phase, options}) when is_atom(phase) and is_list(options), do: {phase, options}
  defp phase_config(phase), do: phase_config({phase, []})
end
