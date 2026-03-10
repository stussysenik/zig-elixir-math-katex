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
      |> render_submit(%{"prompt" => %{"input_query" => "Graph the derivative of x^2"}})

    assert html =~ "Computing"

    rendered = wait_for_render(view, "Proof complete")
    assert rendered =~ "Proof complete"
    assert rendered =~ "2*x"
    assert rendered =~ "Graph the derivative of x^2"
  end

  test "desmos layer can be toggled off", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#desmos-surface")

    view
    |> element("[data-testid='toggle-desmos']")
    |> render_click()

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
