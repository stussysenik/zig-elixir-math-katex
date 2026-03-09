defmodule MathVizWeb.MathOrchestratorLiveTest do
  use MathVizWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the verified-first shell", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "Verified-first mathematics over LiveView"
    assert html =~ "One prompt, one formal gate, three synchronized layers."
  end

  test "submitting a prompt updates the pipeline result", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    html =
      view
      |> element("#solve-form")
      |> render_submit(%{"prompt" => %{"input_query" => "derivative of sin(x)"}})

    assert html =~ "Computing"

    Process.sleep(50)

    rendered = render(view)
    assert rendered =~ "Proof complete"
    assert rendered =~ "cos(x)"
    assert rendered =~ "Verified"
  end

  test "desmos layer can be toggled off", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#desmos-surface")

    view
    |> element("[data-testid='toggle-desmos']")
    |> render_click()

    refute has_element?(view, "#desmos-surface")
  end
end
