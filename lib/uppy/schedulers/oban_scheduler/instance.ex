if Code.ensure_loaded?(Oban) do
  defmodule Uppy.Schedulers.ObanScheduler.Instance do
    @moduledoc false

    @default_name __MODULE__

    @default_opts [
      name: @default_name,
      notifier: Oban.Notifiers.PG,
      repo: Uppy.Support.Repo,
      queues: [
        abort_expired_multipart_upload: 5,
        abort_expired_upload: 5,
        move_to_destination: 5
      ],
      testing: (if Mix.env() === :test, do: :manual, else: :disabled)
    ]

    def start_link(opts \\ []) do
      @default_opts
      |> Keyword.merge(opts)
      |> Oban.start_link()
    end

    def child_spec(opts) do
      opts = Keyword.merge(@default_opts, opts)

      %{
        id: opts[:name],
        start: {__MODULE__, :start_link, [opts]}
      }
    end

    def insert(worker, params) when is_atom(worker) do
      insert(worker, params, [])
    end

    def insert(%{data: %{queue: queue}} = changeset, opts) do
      queue
      |> lookup_name(opts)
      |> Oban.insert(changeset, opts)
    end

    def insert(worker, params, opts) do
      params
      |> worker.new(opts[:worker] || [])
      |> insert(opts)
    end

    defp lookup_name(queue, opts) do
      with {_, val} <-
        opts
        |> Keyword.get(:oban_instances, Uppy.Config.get_app_env(:oban_instances) || [])
        |> Enum.find(oban_name(opts), fn
          {k, _} -> to_string(k) === to_string(queue)
        end) do
        val
      end
    end

    defp oban_name(opts) do
      opts[:scheduler][:name] || @default_name
    end
  end
end
