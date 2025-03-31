if Code.ensure_loaded?(Oban) do
  defmodule Uppy.Schedulers.ObanScheduler.Instance do
    @moduledoc false

    @name __MODULE__

    @default_opts [
      notifier: Oban.Notifiers.PG,
      repo: Uppy.Support.Repo
    ]

    def start_link(opts \\ []) do
      default_opts()
      |> Keyword.merge(opts)
      |> Keyword.put(:name, @name)
      |> Oban.start_link()
    end

    def child_spec(opts) do
      opts = Keyword.merge(default_opts(), opts)

      %{
        id: @name,
        start: {__MODULE__, :start_link, [opts]}
      }
    end

    def insert(changeset, opts) do
      Oban.insert(@name, changeset, opts)
    end

    defp default_opts do
      Keyword.merge(@default_opts, Uppy.Config.get_app_config(__MODULE__) || [])
    end
  end
end
