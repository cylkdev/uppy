defmodule Uppy.Hub do
  @moduledoc """
  Hub
  """

  alias Uppy.Hub.Adapter
  alias Uppy.PathBuilder

  @default_path_builder_module Uppy.PathBuilders.CommonPathBuilder

  def build_object_path(hub, action, struct, unique_identifier, params, opts) do
    if function_exported?(hub, :build_object_path, 4) do
      Adapter.build_object_path(hub, action, struct, unique_identifier, params)
    else
      params =
        if function_exported?(hub, :before_build_object_path, 2) do
          Adapter.before_build_object_path(hub, action, params)
        else
          params
        end

      module =
        Adapter.path_builder_module(hub) ||
          opts[:path_builder_module] ||
          @default_path_builder_module

      PathBuilder.build_object_path(module, action, struct, unique_identifier, params)
    end
  end

  defmacro __using__(opts) do
    quote do
      opts = unquote(opts)

      alias Uppy.Hub.Adapter

      @behaviour Uppy.Hub.Adapter

      opts =
        opts[:app]
        |> Application.get_env(__MODULE__, [])
        |> Keyword.merge(opts)
        |> Adapter.validate_definition!()

      @app opts[:app]

      @db_action_module opts[:db_action_module]

      @http_module opts[:http_module]

      @scheduler_module opts[:scheduler_module]

      @storage_module opts[:storage_module]

      @impl Uppy.Hub.Adapter
      def app, do: @app

      @impl Uppy.Hub.Adapter
      def db_action_module, do: @db_action_module

      @impl Uppy.Hub.Adapter
      def http_module, do: @http_module

      @impl Uppy.Hub.Adapter
      def scheduler_module, do: @scheduler_module

      @impl Uppy.Hub.Adapter
      def storage_module, do: @storage_module
    end
  end
end
