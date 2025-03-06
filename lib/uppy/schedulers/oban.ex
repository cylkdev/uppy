if Code.ensure_loaded?(Oban) do
  defmodule Uppy.Schedulers.Oban do
    @moduledoc false

    @name __MODULE__

    def start_link(opts \\ []) do
      opts
      |> configure_opts()
      |> Oban.start_link()
    end

    def child_spec(opts \\ []) do
      opts = configure_opts(opts)

      %{
        id: opts[:name],
        start: {__MODULE__, :start_link, [opts]}
      }
    end

    defp configure_opts(opts) do
      Uppy.Config.app()
      |> Application.get_env(__MODULE__, [])
      |> Keyword.merge(opts)
      |> Keyword.put(:name, @name)
      |> ensure_repo_configured!()
    end

    defp ensure_repo_configured!(opts) do
      if is_nil(opts[:repo]) do
        raise ArgumentError, "Option `:repo` required, got: #{inspect(opts, pretty: true)}"
      end

      opts
    end

    def cancel_job(job_or_id) do
      Oban.cancel_job(@name, job_or_id)
    end

    def check_queue(opts) do
      Oban.check_queue(@name, opts)
    end

    def config do
      Oban.config(@name)
    end

    def drain_queue(opts) do
      Oban.drain_queue(@name, opts)
    end

    def insert(changeset, opts \\ []) do
      Oban.insert(@name, changeset, opts)
    end

    def insert(multi, multi_name, changeset, opts \\ []) do
      Oban.insert(@name, multi, multi_name, changeset, opts)
    end

    def insert!(changeset, opts \\ []) do
      Oban.insert!(@name, changeset, opts)
    end

    def insert_all(changesets, opts) do
      Oban.insert_all(@name, changesets, opts)
    end

    def insert_all(multi, multi_name, changesets, opts) do
      Oban.insert_all(@name, multi, multi_name, changesets, opts)
    end

    def start_queue(opts) do
      Oban.start_queue(@name, opts)
    end

    def pause_queue(opts) do
      Oban.pause_queue(@name, opts)
    end

    def pause_all_queues(opts \\ []) do
      Oban.pause_all_queues(@name, opts)
    end

    def resume_queue(opts) do
      Oban.resume_queue(@name, opts)
    end

    def resume_all_queues(opts \\ []) do
      Oban.resume_all_queues(@name, opts)
    end

    def scale_queue(opts) do
      Oban.scale_queue(@name, opts)
    end

    def stop_queue(opts) do
      Oban.stop_queue(@name, opts)
    end

    def retry_job(job_or_id) do
      Oban.retry_job(@name, job_or_id)
    end
  end
end
