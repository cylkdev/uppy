if Uppy.Utils.application_loaded?(:ecto_shorts) do
  defmodule Uppy.EctoShortAction do
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

    @type adapter :: Uppy.Adapter.Action.adapter()
    @type id :: Uppy.Adapter.Action.id()
    @type query :: Uppy.Adapter.Action.query()
    @type queryable :: Uppy.Adapter.Action.queryable()
    @type schema_data :: Uppy.Adapter.Action.schema_data()
    @type params :: Uppy.Adapter.Action.params()
    @type options :: Uppy.Adapter.Action.options()

    @type t_res(t) :: Uppy.Adapter.Action.t_res(t)

    @impl Uppy.Adapter.Action
    @doc """
    Implementation for `c:Uppy.Adapter.Action.all/3`.

    See `EctoShorts.Actions.all/3` for documentation.
    """
    @spec all(
            query :: query(),
            params :: params(),
            options :: options()
          ) :: list(schema_data())
    def all(query, params, options) do
      EctoShorts.Actions.all(query, params, options)
    end

    @impl Uppy.Adapter.Action
    @doc """
    Implementation for `c:Uppy.Adapter.Action.create/3`.

    See `EctoShorts.Actions.create/3` for documentation.
    """
    @spec create(
            schema :: queryable(),
            params :: params(),
            options :: options()
          ) :: t_res(schema_data())
    def create(schema, params, options) do
      EctoShorts.Actions.create(schema, params, options)
    end

    @impl Uppy.Adapter.Action
    @doc """
    Implementation for `c:Uppy.Adapter.Action.find/3`.

    See `EctoShorts.Actions.find/3` for documentation.
    """
    @spec find(
      schema :: queryable(),
      params :: params(),
      options :: options()
    ) :: t_res(schema_data())
    def find(schema, params, options) do
      EctoShorts.Actions.find(schema, params, options)
    end

    @impl Uppy.Adapter.Action
    @doc """
    Implementation for `c:Uppy.Adapter.Action.update/4`.

    See `EctoShorts.Actions.update/4` for documentation.
    """
    @spec update(
            schema :: queryable(),
            id_or_schema_data :: id() | schema_data(),
            params :: params(),
            options :: options()
          ) :: t_res(schema_data())
    def update(schema, id_or_schema_data, params, options) do
      EctoShorts.Actions.update(schema, id_or_schema_data, params, options)
    end

    @impl Uppy.Adapter.Action
    @doc """
    Implementation for `c:Uppy.Adapter.Action.delete/2`.

    See `EctoShorts.Actions.delete/2` for documentation.
    """
    @spec delete(
            schema_data :: struct(),
            options :: options()
          ) :: t_res(schema_data())
    def delete(%_{} = schema_data, options) do
      EctoShorts.Actions.delete(schema_data, options)
    end

    @impl Uppy.Adapter.Action
    @doc """
    Implementation for `c:Uppy.Adapter.Action.delete/2`.

    See `EctoShorts.Actions.delete/3` for documentation.
    """
    @spec delete(
            schema :: queryable(),
            id :: id(),
            options :: options()
          ) :: t_res(schema_data())
    def delete(schema, id, options) do
      EctoShorts.Actions.delete(schema, id, options)
    end

    @impl Uppy.Adapter.Action
    @doc """
    Implementation for `c:Uppy.Adapter.Action.transaction/2`.

    Executes a repo transaction.
    """
    @spec transaction(
            func :: function(),
            options :: options()
          ) :: t_res(schema_data())
    def transaction(func, options)
        when is_function(func, 1) or is_function(func, 0) do
      fn repo ->
        func
        |> execute_transaction(repo)
        |> maybe_rollback_on_error(repo, options)
      end
      |> repo!(options).transaction(options)
      |> handle_transaction_response()
    end

    defp execute_transaction(func, repo) when is_function(func, 1), do: func.(repo)
    defp execute_transaction(func, _repo) when is_function(func, 0), do: func.()

    defp maybe_rollback_on_error(response, repo, options) do
      if Keyword.get(options, :rollback_on_error, true) do
        case response do
          {:error, _} = error -> repo.rollback(error)
          :error -> repo.rollback(:error)
          res -> res
        end
      else
        response
      end
    end

    defp handle_transaction_response({:ok, {:ok, _} = ok}), do: ok
    defp handle_transaction_response({:ok, {:error, _} = error}), do: error
    defp handle_transaction_response({:error, {:error, _} = error}), do: error
    defp handle_transaction_response(term), do: term

    defp repo!(options) do
      with nil <- Keyword.get(options, :repo, EctoShorts.Config.repo()) do
        raise """
        The option `:repo` cannot be nil.

        To fix this error you can:

        - Pass a repo module to the option `:repo`.

        - Add the `:repo` option to the `:ecto_shorts` application configuration, for example:

          ```
          config :ecto_shorts, :repo, YourApp.Repo
          ```
        """
      end
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
