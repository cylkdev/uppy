defmodule Uppy.Core.Definition do
  @definition [
    bucket: [
      type: :string,
      required: true,
      doc: "Bucket name"
    ],
    storage_adapter: [
      type: {:custom, __MODULE__, :validate_type, [:non_nil_atom]},
      required: true,
      doc: "Storage module"
    ],
    scheduler_adapter: [
      type: {:custom, __MODULE__, :validate_type, [:non_nil_atom]},
      required: true,
      doc: "Uppy worker module"
    ],
    resource_name: [
      type: :string,
      required: true,
      doc: "Resource name"
    ],
    permanent_object_key_adapter: [
      type: {:custom, __MODULE__, :validate_type, [:non_nil_atom]},
      required: true,
      doc: "Object key module for permanent uploads"
    ],
    temporary_object_key_adapter: [
      type: {:custom, __MODULE__, :validate_type, [:non_nil_atom]},
      required: true,
      doc: "Object key module for temporary uploads"
    ],
    parent_schema: [
      type: {:custom, __MODULE__, :validate_type, [:non_nil_atom]},
      required: true,
      doc: "Association ID source name"
    ],
    parent_association_source: [
      type: {:custom, __MODULE__, :validate_type, [:non_nil_atom]},
      required: true,
      doc: "Association ID source name"
    ],
    queryable_primary_key_source: [
      required: true,
      type: {:custom, __MODULE__, :validate_type, [:non_nil_atom]},
      doc: "Primary key source name"
    ],
    owner_schema: [
      type: {:custom, __MODULE__, :validate_type, [:non_nil_atom]},
      required: true,
      doc: "Owner Ecto.Schema Module"
    ],
    queryable_owner_association_source: [
      type: {:custom, __MODULE__, :validate_type, [:non_nil_atom]},
      required: true,
      doc: "Owner Schema ID source name"
    ],
    owner_primary_key_source: [
      type: {:custom, __MODULE__, :validate_type, [:non_nil_atom]},
      required: true,
      doc: "Owner Schema ID source name"
    ],
    owner_partition_source: [
      type: :atom,
      required: true,
      doc: "Name of the `key` on the owner schema to use for partitioning permanent uploads."
    ]
  ]

  @doc false
  @spec definition :: Keyword.t()
  def definition, do: @definition

  @doc false
  @spec validate(attrs :: Keyword.t()) ::
          {:ok, Keyword.t()} | {:error, NimbleOptions.ValidationError.t()}
  def validate(attrs), do: NimbleOptions.validate(attrs, @definition)

  @doc false
  @spec validate!(attrs :: Keyword.t()) :: Keyword.t()
  def validate!(attrs), do: NimbleOptions.validate!(attrs, @definition)

  @doc false
  @spec validate_type(term(), term()) :: {:ok, term()} | {:error, String.t()}
  def validate_type(term, :non_nil_atom) do
    cond do
      is_atom(term) and is_nil(term) === false -> {:ok, term}
      is_nil(term) -> {:error, "cannot be nil"}
      true -> {:error, "must be an atom and not nil"}
    end
  end
end
