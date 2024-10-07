if Uppy.Utils.application_loaded?(:ecto_shorts) do
  defmodule Uppy.Actions.EctoAction do
    @moduledoc """
    Implements the `Uppy.Adapter.Action` behaviour.

    This adapter is a simple wrapper for `EctoShorts.Actions`.

    ### Getting started

    Add the `:ecto_shorts` dependency to your mix.exs file:

    ```elixir
    {:ecto_shorts, "~> 2.3", optional: true}
    ```

    Add your `ecto_shorts` configuration to your config.exs file:

    ```elixir
    config :ecto_shorts,
      repo: YourApp.Repo,
      error_module: EctoShorts.Actions.Error
    ```

    See `EctoShorts` for more documentation.
    """
    @behaviour Uppy.Adapter.Action

    alias EctoShorts.Actions

    @impl Uppy.Adapter.Action
    def all(query, params, opts) do
      Actions.all(query, params, opts)
    end

    @impl Uppy.Adapter.Action
    def create(schema, params, opts) do
      Actions.create(schema, params, opts)
    end

    @impl Uppy.Adapter.Action
    def find(schema, params, opts) do
      Actions.find(schema, params, opts)
    end

    @impl Uppy.Adapter.Action
    def update(schema, id_or_schema_data, params, opts) do
      Actions.update(schema, id_or_schema_data, params, opts)
    end

    @impl Uppy.Adapter.Action
    def delete(%_{} = schema_data, opts) do
      Actions.delete(schema_data, opts)
    end

    @impl Uppy.Adapter.Action
    def delete(schema, id, opts) do
      Actions.delete(schema, id, opts)
    end

    @impl Uppy.Adapter.Action
    def transaction(func, opts) do
      Actions.transaction(func, opts)
    end
  end
else
  if Uppy.Config.action_adapter() === Uppy.Adapter.Action do
    raise """
    The config `:action_adapter` is set to `Uppy.Adapter.Action` and
    a required dependency is missing.

    To fix this error you can do one of the following:

    - Add the `:ecto_shorts` dependency to your mix.exs:

      ```
      # mix.exs
      defp deps do
        [
          {:ecto_shorts, "~> 2.3"}
        ]
      end
      ```

    - Set the config `:action_adapter` to a different module:

      ```
      # config.exs
      config :uppy, :action_adapter, YourApp.ActionsModule
      ```
    """
  end
end
