defmodule Uppy.Uploader.DBActionTemplate do
  @moduledoc false

  alias Uppy.{DBAction, Uploader}

  def db_all(adapter, params \\ %{}, opts \\ []) do
    adapter
    |> Uploader.query()
    |> DBAction.all(params, opts)
  end

  def db_create(adapter, params, opts \\ []) do
    adapter
    |> Uploader.query()
    |> DBAction.create(params, opts)
  end

  def db_find(adapter, params, opts \\ []) do
    adapter
    |> Uploader.query()
    |> DBAction.find(params, opts)
  end

  def db_update(adapter, params_or_struct, update_params, opts \\ []) do
    adapter
    |> Uploader.query()
    |> DBAction.update(params_or_struct, update_params, opts)
  end

  def db_delete(adapter, id_or_struct, opts \\ []) do
    adapter
    |> Uploader.query()
    |> DBAction.delete(id_or_struct, opts)
  end

  def quoted_ast(opts \\ []) do
    quote do
      opts = unquote(opts)

      alias Uppy.Uploader.DBActionTemplate

      @repo opts[:repo]

      def repo, do: @repo

      def db_all(adapter, params \\ %{}, opts \\ []) do
        DBActionTemplate.db_all(adapter, params, maybe_put_repo(opts))
      end

      def db_create(adapter, params, opts \\ []) do
        DBActionTemplate.db_create(adapter, params, maybe_put_repo(opts))
      end

      def db_find(adapter, params, opts \\ []) do
        DBActionTemplate.db_find(adapter, params, maybe_put_repo(opts))
      end

      def db_update(adapter, params_or_struct, update_params, opts \\ []) do
        DBActionTemplate.db_update(adapter, params_or_struct, update_params, maybe_put_repo(opts))
      end

      def db_delete(adapter, id_or_struct, opts \\ []) do
        DBActionTemplate.db_delete(adapter, id_or_struct, maybe_put_repo(opts))
      end

      defp maybe_put_repo(opts) do
        if is_nil(@repo) do
          opts
        else
          Keyword.put_new(opts, :repo, @repo)
        end
      end
    end
  end
end
