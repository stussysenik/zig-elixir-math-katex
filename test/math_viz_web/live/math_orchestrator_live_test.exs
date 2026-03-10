defmodule MathVizWeb.MathOrchestratorLiveTest do
  use MathVizWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the minimal shell with only nav and command bar", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/")

    assert html =~ "MathViz"
    assert has_element?(view, "#solve-form")
    assert has_element?(view, "[data-testid='query-input']")
    refute html =~ "One prompt, one formal gate"
    refute has_element?(view, "#katex-output")
    refute has_element?(view, "[data-testid='proof-state']")
    refute has_element?(view, "#desmos-surface")
    refute has_element?(view, "#geogebra-surface")
  end

  test "submitting a prompt reveals the verified output and default graph tab", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    _html =
      view
      |> element("#solve-form")
      |> render_submit(%{"prompt" => %{"input_query" => "Graph the derivative of x^2"}})

    rendered = wait_for_render(view, "Proof complete")
    assert rendered =~ "Graph the derivative of x^2"
    assert rendered =~ "2*x"
    assert has_element?(view, "#katex-output")
    assert has_element?(view, "[data-testid='proof-state']")
    assert has_element?(view, "#desmos-surface")
    refute has_element?(view, "#geogebra-surface")
  end

  test "graph tabs switch the rendered engine surface", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("#solve-form")
    |> render_submit(%{"prompt" => %{"input_query" => "Graph the derivative of x^2"}})

    _rendered = wait_for_render(view, "Proof complete")

    assert has_element?(view, "#desmos-surface")
    refute has_element?(view, "#geogebra-surface")

    view
    |> element("[data-testid='graph-tab-geogebra']")
    |> render_click()

    assert has_element?(view, "#geogebra-surface")
    refute has_element?(view, "#desmos-surface")
  end

  defp wait_for_render(view, needle, attempts \\ 20)

  defp wait_for_render(view, needle, attempts) when attempts > 0 do
    rendered = render(view)

    if rendered =~ needle do
      rendered
    else
      Process.sleep(25)
      wait_for_render(view, needle, attempts - 1)
    end
  end

  defp wait_for_render(view, _needle, 0), do: render(view)
end
