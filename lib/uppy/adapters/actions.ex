if Code.ensure_loaded?(EctoShorts) do
  defmodule Uppy.Adapters.Actions do
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
    alias EctoShorts.Actions

    alias Uppy.Adapter

    @behaviour Adapter.Actions

    @type t_res(t) :: {:ok, t} | {:error, term()}

    @impl Adapter.Actions
    @doc """
    See `EctoShorts.Actions.create/3` for documentation.
    """
    @spec create(
            schema :: module(),
            params :: map(),
            options :: Keyword.t()
          ) :: t_res(struct())
    def create(schema, params, options) do
      Actions.create(schema, params, options)
    end

    @impl Adapter.Actions
    @doc """
    See `EctoShorts.Actions.find/3` for documentation.
    """
    @spec find(
            schema :: module(),
            params :: map(),
            options :: Keyword.t()
          ) :: t_res(struct())
    def find(schema, params, options) do
      Actions.find(schema, params, options)
    end

    @impl Adapter.Actions
    @doc """
    See `EctoShorts.Actions.update/4` for documentation.
    """
    @spec update(
            schema :: module(),
            id_of_schema_data :: non_neg_integer() | struct(),
            params :: map(),
            options :: Keyword.t()
          ) :: t_res(struct())
    def update(schema, id_or_schema_data, params, options) do
      Actions.update(schema, id_or_schema_data, params, options)
    end

    @impl Adapter.Actions
    @doc """
    See `EctoShorts.Actions.delete/2` for documentation.
    """
    @spec delete(
            schema_data :: struct(),
            options :: Keyword.t()
          ) :: t_res(struct())
    def delete(%_{} = schema_data, options) do
      Actions.delete(schema_data, options)
    end

    @impl Adapter.Actions
    @doc """
    See `EctoShorts.Actions.delete/3` for documentation.
    """
    @spec delete(
            schema :: module(),
            id :: term(),
            options :: Keyword.t()
          ) :: t_res(struct())
    def delete(schema, id, options) do
      Actions.delete(schema, id, options)
    end

    @impl Adapter.Actions
    @doc """
    Executes a repo transaction.
    """
    @spec transaction(
            func :: function(),
            options :: Keyword.t()
          ) :: t_res(struct())
    def transaction(func, options) do
      fn repo ->
        func
        |> execute_transaction(repo)
        |> maybe_rollback(repo)
      end
      |> repo!(options).transaction(options)
      |> handle_transaction_response()
    end

    defp execute_transaction(func, repo) when is_function(func, 1), do: func.(repo)
    defp execute_transaction(func, _repo) when is_function(func, 0), do: func.()

    defp maybe_rollback({:error, _} = error, repo), do: repo.rollback(error)
    defp maybe_rollback({:ok, _} = ok, _repo), do: ok

    defp handle_transaction_response({_status, {:ok, _} = ok}), do: ok
    defp handle_transaction_response({_status, {:error, _} = error}), do: error
    defp handle_transaction_response(term), do: term

    defp repo!(options), do: Keyword.get(options, :repo, EctoShorts.Config.repo())
  end
else
  if Uppy.Config.actions_adapter() === Uppy.Adapters.Actions do
    raise """
    The config `:actions_adapter` is set to `Uppy.Adapters.Actions` and
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

    - Set the config `:actions_adapter` to a different module:

      ```
      # config.exs
      config :uppy, :actions_adapter, YourApp.ActionsModule
      ```
    """
  end
end
