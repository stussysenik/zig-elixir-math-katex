defmodule MathViz.API.VisionInput do
  @moduledoc "Validated vision input shared by the API and LiveView upload flow."

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:filename, :string)
    field(:mime, :string)
    field(:content, :binary)
    field(:size, :integer)
  end

  @mime_types ~w(image/jpeg image/png image/webp)
  @max_size 5_242_880

  @type t :: %__MODULE__{
          filename: String.t() | nil,
          mime: String.t() | nil,
          content: binary() | nil,
          size: non_neg_integer() | nil
        }

  @spec mime_types() :: [String.t()]
  def mime_types, do: @mime_types

  @spec max_size() :: pos_integer()
  def max_size, do: @max_size

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(vision_input, attrs) do
    vision_input
    |> cast(attrs, [:filename, :mime, :content, :size])
    |> validate_required([:mime, :content, :size])
    |> validate_inclusion(:mime, @mime_types)
    |> validate_number(:size, greater_than: 0, less_than_or_equal_to: @max_size)
    |> validate_change(:content, fn :content, content ->
      if is_binary(content) and byte_size(content) > @max_size do
        [content: "must be 5MB or smaller"]
      else
        []
      end
    end)
  end
end
