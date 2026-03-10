defmodule MathViz.Contracts.AIResponse do
  @moduledoc "Validated AI boundary payload."
  use Ecto.Schema
  import Ecto.Changeset

  @derive Jason.Encoder
  @primary_key false
  embedded_schema do
    field(:mode, Ecto.Enum, values: [:computation, :chat], default: :computation)
    field(:reasoning_steps, {:array, :string}, default: [])
    field(:raw_latex, :string)
    field(:sympy_executable, :string)
    embeds_many(:desmos_expressions, MathViz.Contracts.DesmosExpression)
    field(:chat_reply, :string)
  end

  @type mode :: :computation | :chat

  @type t :: %__MODULE__{
          mode: mode(),
          reasoning_steps: [String.t()],
          raw_latex: String.t() | nil,
          sympy_executable: String.t() | nil,
          desmos_expressions: [MathViz.Contracts.DesmosExpression.t()],
          chat_reply: String.t() | nil
        }

  @doc false
  def changeset(response \\ %__MODULE__{}, attrs) do
    response
    |> cast(attrs, [:mode, :reasoning_steps])
    |> validate_required([:mode, :reasoning_steps])
    |> validate_length(:reasoning_steps, min: 1)
    |> cast_mode_specific_fields(attrs)
  end

  defp cast_mode_specific_fields(changeset, attrs) do
    case get_field(changeset, :mode) do
      :computation ->
        changeset
        |> cast(attrs, [:raw_latex, :sympy_executable])
        |> validate_required([:raw_latex, :sympy_executable])
        |> cast_embed(:desmos_expressions,
          with: &MathViz.Contracts.DesmosExpression.changeset/2,
          required: true
        )

      :chat ->
        changeset
        |> cast(attrs, [:chat_reply])
        |> validate_required([:chat_reply])
        |> put_embed(:desmos_expressions, [])

      _ ->
        changeset
    end
  end
end
