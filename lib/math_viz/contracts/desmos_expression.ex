defmodule MathViz.Contracts.DesmosExpression do
  @moduledoc "Single Desmos expression payload."
  use Ecto.Schema
  import Ecto.Changeset

  @derive Jason.Encoder
  @primary_key false
  embedded_schema do
    field(:id, :string)
    field(:latex, :string)
  end

  @type t :: %__MODULE__{
          id: String.t() | nil,
          latex: String.t() | nil
        }

  @doc false
  def changeset(expression \\ %__MODULE__{}, attrs) do
    expression
    |> cast(attrs, [:id, :latex])
    |> validate_required([:id, :latex])
  end
end
