defmodule MathViz.API.SolveRequest do
  @moduledoc "Headless solve request validated with Ecto embedded schemas."

  use Ecto.Schema

  import Ecto.Changeset

  alias MathViz.API.VisionInput

  @primary_key false
  embedded_schema do
    field(:query, :string, default: "")
    embeds_one(:vision, VisionInput, on_replace: :update)
  end

  @max_query_length 4_000
  @default_vision_query "Analyze the uploaded image and extract the mathematical problem."

  @type t :: %__MODULE__{
          query: String.t(),
          vision: VisionInput.t() | nil
        }

  @spec new(map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def new(params) when is_map(params) do
    params
    |> normalize_attrs()
    |> then(&changeset(%__MODULE__{}, &1))
    |> apply_action(:validate)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(request, attrs) do
    request
    |> cast(attrs, [:query])
    |> update_change(:query, &String.trim/1)
    |> validate_length(:query, max: @max_query_length)
    |> cast_embed(:vision, with: &VisionInput.changeset/2, required: false)
    |> maybe_add_vision_error(attrs)
    |> validate_query_or_vision()
  end

  @spec effective_query(t()) :: String.t()
  def effective_query(%__MODULE__{query: "", vision: %VisionInput{}}), do: @default_vision_query
  def effective_query(%__MODULE__{query: query}), do: String.trim(query)

  @spec has_vision?(t()) :: boolean()
  def has_vision?(%__MODULE__{vision: %VisionInput{}}), do: true
  def has_vision?(_request), do: false

  @spec query_metadata(t()) :: map()
  def query_metadata(%__MODULE__{} = request) do
    %{
      has_vision: has_vision?(request),
      vision:
        case request.vision do
          %VisionInput{} = vision ->
            %{
              filename: vision.filename,
              mime: vision.mime,
              size: vision.size
            }

          _ ->
            nil
        end
    }
  end

  defp validate_query_or_vision(changeset) do
    query = get_field(changeset, :query, "") |> String.trim()
    vision = get_field(changeset, :vision)

    if query == "" and is_nil(vision) do
      add_error(changeset, :query, "enter a query or attach an image")
    else
      changeset
    end
  end

  defp maybe_add_vision_error(changeset, %{"vision_error" => message}) when is_binary(message) do
    add_error(changeset, :vision, message)
  end

  defp maybe_add_vision_error(changeset, _attrs), do: changeset

  defp normalize_attrs(params) do
    query =
      params
      |> fetch_value(["query", :query, "input_query", :input_query], "")
      |> normalize_query()

    case normalize_vision(params) do
      {:ok, nil} ->
        %{"query" => query}

      {:ok, vision_attrs} ->
        %{"query" => query, "vision" => vision_attrs}

      {:error, message} ->
        %{"query" => query, "vision_error" => message}
    end
  end

  defp normalize_query(nil), do: ""
  defp normalize_query(query) when is_binary(query), do: query
  defp normalize_query(_query), do: ""

  defp normalize_vision(params) do
    cond do
      is_map(fetch_value(params, ["vision", :vision])) ->
        fetch_value(params, ["vision", :vision])
        |> normalize_vision_map()

      match?(%Plug.Upload{}, fetch_value(params, ["image", :image])) ->
        params
        |> fetch_value(["image", :image])
        |> normalize_upload()

      present?(fetch_value(params, ["image_base64", :image_base64])) ->
        normalize_base64(
          fetch_value(params, ["image_base64", :image_base64]),
          fetch_value(params, ["image_mime", :image_mime]),
          fetch_value(params, ["image_filename", :image_filename], "upload-image")
        )

      true ->
        {:ok, nil}
    end
  end

  defp normalize_vision_map(%{bytes: bytes} = vision) when is_binary(bytes) do
    build_vision_attrs(
      bytes,
      Map.get(vision, :mime) || Map.get(vision, "mime"),
      Map.get(vision, :filename) || Map.get(vision, "filename") || "uploaded-image",
      Map.get(vision, :size) || Map.get(vision, "size")
    )
  end

  defp normalize_vision_map(%{"bytes" => bytes} = vision) when is_binary(bytes) do
    build_vision_attrs(
      bytes,
      Map.get(vision, "mime"),
      Map.get(vision, "filename") || "uploaded-image",
      Map.get(vision, "size")
    )
  end

  defp normalize_vision_map(_vision), do: {:error, "image payload is invalid"}

  defp normalize_upload(%Plug.Upload{} = upload) do
    case File.read(upload.path) do
      {:ok, bytes} ->
        build_vision_attrs(
          bytes,
          upload.content_type || MIME.from_path(upload.filename),
          upload.filename,
          nil
        )

      {:error, reason} ->
        {:error, "could not read uploaded image: #{:file.format_error(reason)}"}
    end
  end

  defp normalize_base64(base64, mime, filename) when is_binary(base64) do
    {decoded_mime, encoded} = split_data_uri(base64)
    mime = mime || decoded_mime

    encoded
    |> String.replace(~r/\s+/, "")
    |> Base.decode64()
    |> case do
      {:ok, bytes} -> build_vision_attrs(bytes, mime, filename, nil)
      :error -> {:error, "image_base64 must be valid base64"}
    end
  end

  defp normalize_base64(_base64, _mime, _filename),
    do: {:error, "image_base64 must be valid base64"}

  defp build_vision_attrs(bytes, mime, filename, size_override) when is_binary(bytes) do
    %{
      "filename" => normalize_filename(filename),
      "mime" => mime,
      "content" => bytes,
      "size" => size_override || byte_size(bytes)
    }
    |> then(&VisionInput.changeset(%VisionInput{}, &1))
    |> apply_action(:validate)
    |> case do
      {:ok, vision_input} ->
        {:ok,
         %{
           "filename" => vision_input.filename,
           "mime" => vision_input.mime,
           "content" => vision_input.content,
           "size" => vision_input.size
         }}

      {:error, changeset} ->
        {:error, first_error(changeset)}
    end
  end

  defp normalize_filename(filename) when is_binary(filename) and filename != "", do: filename
  defp normalize_filename(_filename), do: "uploaded-image"

  defp split_data_uri("data:" <> rest) do
    case String.split(rest, ";base64,", parts: 2) do
      [mime, encoded] -> {mime, encoded}
      _ -> {nil, rest}
    end
  end

  defp split_data_uri(base64), do: {nil, base64}

  defp fetch_value(map, keys, default \\ nil) do
    Enum.find_value(keys, default, &Map.get(map, &1))
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false

  defp first_error(changeset) do
    changeset
    |> traverse_errors(fn {message, _opts} -> message end)
    |> Enum.reduce(nil, fn
      {_field, [message | _]}, nil -> message
      _, acc -> acc
    end) || "request is invalid"
  end
end
