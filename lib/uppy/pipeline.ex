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

  @type error_message :: Uppy.Error.error_message()
  @type opts :: keyword()
  @type input :: term()
  @type phase :: module() | {module(), opts()}
  @type phases :: list(phase())
  @type pipeline :: phases()
  @type pipeline_response ::  {:ok, result :: result(), done :: phases()} |
                              {:error, error_message :: error_message(), done :: phases()}

  @type result :: term()

  @doc """
  Returns a list of phases.
  """
  @spec phases(adapter :: module(), opts :: opts()) :: list()
  @spec phases(adapter :: module()) :: list()
  def phases(adapter, opts \\ []) do
    adapter.phases(opts)
  end

  @doc """
  Flattens a list of phases and executes each phase
  sequentially.

  ### Examples

      iex> Uppy.Pipeline.run("input", [Uppy.Support.Phases.EchoPhase])
      {:ok, %{input: "input", opts: []}, [Uppy.Support.Phases.EchoPhase]}

      iex> Uppy.Pipeline.run("input", [{Uppy.Support.Phases.EchoPhase, resource: "resource"}])
      {:ok, %{input: "input", opts: [resource: "resource"]}, [Uppy.Support.Phases.EchoPhase]}
  """
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
  opts.

  ## Examples

  Replace a simple phase (without opts):

      iex> Uppy.Pipeline.replace([A, B, C], B, X)
      [A, X, C]

  Replace a phase with opts, retaining them:

      iex> Uppy.Pipeline.replace([A, {B, [name: "Thing"]}, C], B, X)
      [A, {X, [name: "Thing"]}, C]

  Replace a phase with opts, overriding them:

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
        true -> do_replace(candidate, replacement)
        false -> candidate
      end
    end)
  end

  defp do_replace(candidate, replacement) do
    case phase_invocation(candidate) do
      {_, []} ->
        replacement

      {_, opts} ->
        if is_atom(replacement) do
          {replacement, opts}
        else
          replacement
        end
    end
  end

  defp phase_invocation({phase, opts}) when is_list(opts) do
    {phase, opts}
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

    index = beginning |> length() |> Access.at()

    item = get_in(pipeline, [index])

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
      {:ok, %{input: %{likes: 10}, opts: []}, [Uppy.Support.Phases.EchoPhase]}
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
    {phase, opts} = phase_config(phase)

    case Phase.run(phase, input, opts) do
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

  defp phase_config({phase, opts}) when is_atom(phase) and is_list(opts), do: {phase, opts}
  defp phase_config(phase), do: phase_config({phase, []})
end
