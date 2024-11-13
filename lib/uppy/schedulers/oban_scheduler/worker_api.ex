defmodule Uppy.Schedulers.ObanScheduler.WorkerAPI do
  @moduledoc """
  ...
  """

  @discarded :discarded

  @doc """
  Convert a string to an existing module.

  ### Examples

      iex> Uppy.Schedulers.ObanScheduler.WorkerAPI.string_to_module("Elixir.Uppy.Schedulers.ObanScheduler.WorkerAPI")
      Uppy.Schedulers.ObanScheduler.WorkerAPI
  """
  @spec string_to_module(binary()) :: module()
  def string_to_module(string) do
    string |> String.split(".") |> Module.safe_concat()
  end

  @doc """
  Convert a module to a string.

  ### Examples

      iex> Uppy.Schedulers.ObanScheduler.WorkerAPI.module_to_string(Uppy.Schedulers.ObanScheduler.WorkerAPI)
      "Elixir.Uppy.Schedulers.ObanScheduler.WorkerAPI"
  """
  @spec module_to_string(module()) :: binary()
  def module_to_string(module) do
    to_string(module)
  end

  @doc """
  ...
  """
  @spec query_to_arguments({source :: binary(), query :: Ecto.Queryable.t()}) :: %{
          source: binary(),
          query: binary()
        }
  @spec query_to_arguments(query :: Ecto.Queryable.t()) :: %{source: binary(), query: binary()}
  def query_to_arguments({source, query}) do
    %{source: source, query: module_to_string(query)}
  end

  def query_to_arguments(query) do
    %{query: module_to_string(query)}
  end

  @doc """
  ...
  """
  @spec query_from_arguments(%{binary() => binary()}) :: {binary(), Ecto.Queryable.t()}
  @spec query_from_arguments(%{binary() => binary()}) :: Ecto.Queryable.t()
  def query_from_arguments(%{"source" => source, "query" => query}) do
    {source, string_to_module(query)}
  end

  def query_from_arguments(%{"query" => query}) do
    string_to_module(query)
  end

  @doc """
  ...
  """
  def abort_multipart_upload(bucket, query, id, opts) do
    with {:error, %{code: :not_found} = e} <-
           Uppy.abort_multipart_upload(
             bucket,
             query,
             %{id: id},
             %{status: @discarded},
             opts
           ) do
      {:ok,
       %{
         message: "object or record not found",
         payload: e
       }}
    end
  end

  @doc """
  ...
  """
  def abort_upload(bucket, query, id, opts) do
    with {:error, %{code: :not_found} = e} <-
           Uppy.abort_upload(
             bucket,
             query,
             %{id: id},
             %{status: @discarded},
             opts
           ) do
      {:ok,
       %{
         message: "object or record not found",
         payload: e
       }}
    end
  end

  @doc """
  ...
  """
  def move_upload(bucket, destination_object, query, id, pipeline, opts) do
    Uppy.move_upload(
      bucket,
      destination_object,
      query,
      %{id: id},
      pipeline,
      opts
    )
  end
end
