defmodule Uppy.Core.Context do
  @definition [
    bucket: [
      type: :string,
      required: true,
      doc: "Bucket name."
    ],
    resource_name: [
      type: :string,
      doc: "Resource name.",
      default: "uploads"
    ],
    storage_adapter: [
      type: :atom,
      required: true,
      doc: "Storage adapter module."
    ],
    action_adapter: [
      type: :atom,
      doc: "Database action adapter module.",
      default: Uppy.Adapters.Action
    ],
    temporary_scope_adapter: [
      type: :atom,
      doc: "Temporary scope adapter module.",
      default: Uppy.Adapters.TemporaryScope
    ],
    permanent_scope_adapter: [
      type: :atom,
      doc: "Permanent scope adapter module.",
      default: Uppy.Adapters.PermanentScope
    ]
  ]

  @moduledoc """
  #{NimbleOptions.docs(@definition)}
  """

  alias Uppy.Config

  @enforce_keys [
    :bucket,
    :resource_name,
    :storage_adapter,
    :action_adapter,
    :temporary_scope_adapter,
    :permanent_scope_adapter
  ]

  defstruct @enforce_keys

  @typedoc "bucket"
  @type bucket :: String.t()

  @typedoc "resource name"
  @type resource_name :: String.t()

  @typedoc "adapter module"
  @type adapter :: module()

  @typedoc "context struct"
  @type t :: %__MODULE__{
    bucket: bucket() | nil,
    resource_name: resource_name() | nil,
    storage_adapter: adapter() | nil,
    action_adapter: adapter() | nil,
    temporary_scope_adapter: adapter() | nil,
    permanent_scope_adapter: adapter() | nil
  }

  @doc """
  Returns a struct.

  Raises if options contains a key that does not exist on the struct.

  ### Examples

      iex> Uppy.Core.Context.create!()
  """
  @spec create!(opts :: Keyword.t()) :: t()
  def create!(opts \\ []), do: struct!(__MODULE__, opts)

  @doc """
  Returns a struct.

  ### Examples

      iex> Uppy.Core.Context.create()
  """
  @spec create(opts :: Keyword.t()) :: {:ok, t()}
  def create(opts \\ []), do: {:ok, create!(opts)}

  @doc """
  Returns a struct.

  Raises if a validation error occurs.

  See `&Uppy.Core.Context.validate/1` for detailed documentation.

  ### Examples

      iex> Uppy.Core.Context.validate!()
  """
  @spec validate!(opts :: Keyword.t()) :: t()
  def validate!(opts \\ []) do
    load_config()
    |> Keyword.merge(opts)
    |> Enum.reject(&value_is_nil?/1)
    |> NimbleOptions.validate!(@definition)
    |> create!()
  end

  @doc """
  Returns a struct.

  Options are resolved as follows:

      * Values are read from configuration.
      * The `opts` argument is merged onto the existing configuration values (this replaces existing configuration values with values specified in the argument).
      * Options are validated.

  ### Examples

      iex> Uppy.Core.Context.validate()
  """
  @spec validate(opts :: Keyword.t()) :: {:ok, t()}
  def validate(opts \\ []) do
    with {:ok, opts} <-
      load_config()
      |> Keyword.merge(opts)
      |> Enum.reject(&value_is_nil?/1)
      |> NimbleOptions.validate(@definition) do
      create(opts)
    end
  end

  @doc """
  Returns a keyword list of configuration values.

  The list contains the following keys.

      * `bucket`
      * `resource_name`
      * `storage_adapter`
      * `action_adapter`
      * `temporary_scope_adapter`
      * `permanent_scope_adapter`

  ### Examples

      iex> Uppy.Core.Context.load_config()
  """
  @spec load_config :: Keyword.t()
  def load_config do
    [
      bucket: Config.bucket(),
      resource_name: Config.resource_name(),
      storage_adapter: Config.storage_adapter(),
      action_adapter: Config.action_adapter(),
      temporary_scope_adapter: Config.temporary_scope_adapter(),
      permanent_scope_adapter: Config.permanent_scope_adapter()
    ]
  end

  defp value_is_nil?({_k, nil}), do: true
  defp value_is_nil?({_k, _v}), do: false
end
