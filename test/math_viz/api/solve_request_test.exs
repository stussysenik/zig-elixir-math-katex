defmodule MathViz.API.SolveRequestTest do
  use ExUnit.Case, async: true

  alias MathViz.API.SolveRequest

  test "accepts a base64 image without a text query" do
    params = %{
      "image_base64" =>
        Base.encode64(
          Base.decode64!(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4////fwAJ+wP+X2VINQAAAABJRU5ErkJggg=="
          )
        ),
      "image_mime" => "image/png"
    }

    assert {:ok, request} = SolveRequest.new(params)
    assert request.query == ""
    assert request.vision.mime == "image/png"
    assert SolveRequest.effective_query(request) =~ "uploaded image"
  end

  test "rejects invalid base64 payloads" do
    assert {:error, changeset} =
             SolveRequest.new(%{
               "query" => "",
               "image_base64" => "not-base64",
               "image_mime" => "image/png"
             })

    assert "image_base64 must be valid base64" in errors_on(changeset).vision
  end

  test "rejects unsupported mime types" do
    assert {:error, changeset} =
             SolveRequest.new(%{
               "query" => "Solve this",
               "vision" => %{bytes: "<<pdf>>", mime: "application/pdf", filename: "scan.pdf"}
             })

    assert "is invalid" in errors_on(changeset).vision
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} -> message end)
  end
end
