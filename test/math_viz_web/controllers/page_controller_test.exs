defmodule MathVizWeb.PageControllerTest do
  use MathVizWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")

    html = html_response(conn, 200)
    assert html =~ "MathViz"
    assert html =~ "Enter an equation or natural language query..."
  end
end
