defmodule Uppy.Schedulers.Oban.ObanUtil do
  @moduledoc false
  alias Uppy.Utils

  @default_name Uppy.Oban

  @type opts :: keyword()
  @type schedule :: DateTime.t() | non_neg_integer() | nil
  @type job_changeset :: Oban.Job.changeset()

  def decode_binary_to_term(binary) do
    binary |> Base.decode64!() |> Utils.binary_to_term()
  end

  def encode_term_to_binary(term) do
    term |> Utils.term_to_binary() |> Base.encode64()
  end

  @spec put_schedule(
    opts :: opts(),
    schedule :: schedule()
  ) :: opts()
  def put_schedule(opts, nil), do: opts
  def put_schedule(opts, %DateTime{} = schedule_at), do: Keyword.put(opts, :schedule_at, schedule_at)
  def put_schedule(opts, schedule_in), do: Keyword.put(opts, :schedule_in, schedule_in)

  @spec insert(
    changeset :: job_changeset(),
    schedule :: schedule(),
    opts :: opts()
  ) :: {:ok, Oban.Job.t()} | {:error, job_changeset() | term()}
  def insert(changeset, schedule, opts) do
    default_opts()
    |> Keyword.merge(opts)
    |> oban_name!()
    |> Oban.insert(changeset, put_schedule(opts, schedule))
  end

  defp oban_name!(opts), do: opts[:oban_name]

  defp default_opts do
    [oban_name: @default_name]
  end
end
