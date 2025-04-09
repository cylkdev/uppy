defmodule Uppy.Hub.Adapter do
  @callback app :: module()

  @callback db_action_module :: module()

  @callback http_module :: module()

  @callback scheduler_module :: module()

  @callback before_build_object_path(action :: atom(), params :: map()) :: map()

  @callback build_object_path(
              action :: atom(),
              struct :: struct(),
              unique_identifier :: binary(),
              params :: map()
            ) :: binary()

  @callback storage_module :: module()

  @optional_callbacks build_object_path: 4,
                      before_build_object_path: 2

  @default_db_action_module Uppy.DBActions.SimpleRepo
  @default_http_module Uppy.HTTP.Finch
  @default_scheduler_module Uppy.Schedulers.ObanScheduler
  @default_storage_module Uppy.Storages.S3

  @definition [
    app: [
      type: :atom,
      required: true,
      doc: "The application where this module is configured."
    ],
    db_action_module: [
      type: :atom,
      default: @default_db_action_module,
      doc: "The database action module"
    ],
    http_module: [
      type: :atom,
      default: @default_http_module,
      doc: "The http module"
    ],
    path_builder_module: [
      type: :atom,
      doc: "The path builder module"
    ],
    scheduler_module: [
      type: :atom,
      default: @default_scheduler_module,
      doc: "The scheduler module"
    ],
    storage_module: [
      type: :atom,
      default: @default_storage_module,
      doc: "The storage module"
    ]
  ]

  def definition, do: @definition

  def validate_definition!(opts), do: NimbleOptions.validate!(opts, @definition)

  def app(hub), do: hub.app()

  def db_action_module(hub), do: hub.db_action_module()

  def http_module(hub), do: hub.http_module()

  def scheduler_module(hub), do: hub.scheduler_module()

  def storage_module(hub), do: hub.storage_module()

  def path_builder_module(hub), do: hub.path_builder_module()

  def build_object_path(hub, action, struct, unique_identifier, params) do
    hub.build_object_path(action, struct, unique_identifier, params)
  end

  def before_build_object_path(hub, action, params) do
    hub.before_build_object_path(action, params)
  end
end
