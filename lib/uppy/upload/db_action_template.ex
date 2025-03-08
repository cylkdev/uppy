defmodule Uppy.Upload.DBActionTemplate do
  @moduledoc false

  alias Uppy.{DBAction, Uploader}

  def db_all(uploader, params \\ %{}, opts \\ []) do
    uploader
    |> Uploader.query()
    |> DBAction.all(params, opts)
  end

  def db_create(uploader, params, opts \\ []) do
    uploader
    |> Uploader.query()
    |> DBAction.create(params, opts)
  end

  def db_find(uploader, params, opts \\ []) do
    uploader
    |> Uploader.query()
    |> DBAction.find(params, opts)
  end

  def db_update(uploader, params_or_struct, update_params, opts \\ []) do
    uploader
    |> Uploader.query()
    |> DBAction.update(params_or_struct, update_params, opts)
  end

  def db_delete(uploader, id_or_struct, opts \\ []) do
    uploader
    |> Uploader.query()
    |> DBAction.delete(id_or_struct, opts)
  end

  def quoted_ast(_opts \\ []) do
    quote do
      alias Uppy.Upload.DBActionTemplate

      def db_all(uploader, params \\ %{}, opts \\ []) do
        DBActionTemplate.db_all(uploader, params, opts)
      end

      def db_create(uploader, params, opts \\ []) do
        DBActionTemplate.db_create(uploader, params, opts)
      end

      def db_find(uploader, params, opts \\ []) do
        DBActionTemplate.db_find(uploader, params, opts)
      end

      def db_update(uploader, params_or_struct, update_params, opts \\ []) do
        DBActionTemplate.db_update(uploader, params_or_struct, update_params, opts)
      end

      def db_delete(uploader, id_or_struct, opts \\ []) do
        DBActionTemplate.db_delete(uploader, id_or_struct, opts)
      end
    end
  end
end
