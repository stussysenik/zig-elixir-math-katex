defmodule MathVizWeb.SolveControllerTest do
  use MathVizWeb.ConnCase, async: true

  test "POST /api/solve returns a verified JSON payload for text-only requests", %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/api/solve", Jason.encode!(%{"query" => "Graph the derivative of x^2"}))

    body = json_response(conn, 200)

    assert body["mode"] == "computation"
    assert body["verified"] == true
    assert body["adapter"] == "stub"
    assert body["symbol"]["expression"] == "2*x"
    assert body["proof"]["state"] == "Proof complete"
    assert body["graph"]["desmos"]["expressions"] != []
  end

  test "POST /api/solve returns a chat payload for theory prompts", %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/api/solve", Jason.encode!(%{"query" => "What is an integral?"}))

    body = json_response(conn, 200)

    assert body["mode"] == "chat"
    assert body["verified"] == false
    assert body["chat_reply"] =~ "integral"
    assert body["graph"]["desmos"] == %{}
    assert body["proof"] == %{}
  end

  test "POST /api/solve accepts multipart image uploads", %{conn: conn} do
    upload = png_upload("whiteboard.png")

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> post(~p"/api/solve", %{"query" => "", "image" => upload})

    body = json_response(conn, 200)

    assert body["request"]["has_image"] == true
    assert body["request"]["image"]["filename"] == "whiteboard.png"
    assert body["mode"] == "computation"
    assert body["verified"] == true
    assert body["graph"]["desmos"]["expressions"] != []
  end

  test "POST /api/solve rejects invalid image_base64 payloads", %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")
      |> post(
        ~p"/api/solve",
        Jason.encode!(%{"query" => "", "image_base64" => "bad", "image_mime" => "image/png"})
      )

    body = json_response(conn, 422)

    assert "image_base64 must be valid base64" in body["errors"]["vision"]
  end

  defp png_upload(filename) do
    path = Path.join(System.tmp_dir!(), "#{System.unique_integer([:positive])}-#{filename}")
    File.write!(path, png_fixture())

    %Plug.Upload{
      path: path,
      filename: filename,
      content_type: "image/png"
    }
  end

  defp png_fixture do
    Base.decode64!(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4////fwAJ+wP+X2VINQAAAABJRU5ErkJggg=="
    )
  end
end
