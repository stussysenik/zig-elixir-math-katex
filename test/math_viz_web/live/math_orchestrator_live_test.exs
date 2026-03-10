defmodule MathVizWeb.MathOrchestratorLiveTest do
  use MathVizWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup do
    previous_nlp_mode = Application.get_env(:math_viz, :nlp_mode)
    previous_nim_fallback_mode = Application.get_env(:math_viz, :nim_fallback_mode)
    previous_nvidia_nim = Application.get_env(:math_viz, :nvidia_nim)
    previous_solve_module = Application.get_env(:math_viz, :solve_module)
    previous_solve_test_pid = Application.get_env(:math_viz, :solve_test_pid)
    previous_solve_timeout_ms = Application.get_env(:math_viz, :solve_timeout_ms)

    Application.put_env(:math_viz, :nlp_mode, :stub)
    Application.put_env(:math_viz, :nim_fallback_mode, :fallback)
    Application.put_env(:math_viz, :solve_module, MathViz.TestSupport.InstrumentedSolve)
    Application.put_env(:math_viz, :solve_test_pid, self())
    Application.delete_env(:math_viz, :solve_timeout_ms)

    on_exit(fn ->
      restore_env(:nlp_mode, previous_nlp_mode)
      restore_env(:nim_fallback_mode, previous_nim_fallback_mode)
      restore_env(:nvidia_nim, previous_nvidia_nim)
      restore_env(:solve_module, previous_solve_module)
      restore_env(:solve_test_pid, previous_solve_test_pid)
      restore_env(:solve_timeout_ms, previous_solve_timeout_ms)
    end)

    :ok
  end

  test "renders the minimal shell with only nav and command bar", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/")

    assert html =~ "MathViz"
    assert has_element?(view, "#solve-form")
    assert has_element?(view, "[data-testid='query-input']")
    assert has_element?(view, "[data-testid='vision-upload-trigger']")
    assert html =~ "textbook photos and whiteboard sketches"
    refute html =~ "One prompt, one formal gate"
    refute has_element?(view, "#katex-output")
    refute has_element?(view, "[data-testid='proof-state']")
    refute has_element?(view, "#desmos-surface")
    refute has_element?(view, "#geogebra-surface")
  end

  test "submitting a prompt reveals the verified output and default graph tab", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("#solve-form")
    |> render_submit(%{"prompt" => %{"input_query" => "Graph the derivative of x^2"}})

    rendered = await_completed_render(view, "Graph the derivative of x^2")

    assert rendered =~ "Graph the derivative of x^2"
    assert rendered =~ "2*x"
    assert has_element?(view, "#katex-output")
    assert has_element?(view, "[data-testid='proof-state']")
    assert has_element?(view, "#desmos-surface")
    refute has_element?(view, "#geogebra-surface")
  end

  test "theory prompts render chat output without graph surfaces", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("#solve-form")
    |> render_submit(%{"prompt" => %{"input_query" => "What is an integral?"}})

    rendered = await_completed_render(view, "What is an integral?")

    assert rendered =~ "integral"
    assert has_element?(view, "[data-testid='chat-output']")
    refute has_element?(view, "#katex-output")
    refute has_element?(view, "[data-testid='proof-state']")
    refute has_element?(view, "#desmos-surface")
    refute has_element?(view, "#geogebra-surface")
  end

  test "graph tabs switch the rendered engine surface", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("#solve-form")
    |> render_submit(%{"prompt" => %{"input_query" => "Graph the derivative of x^2"}})

    _rendered = await_completed_render(view, "Graph the derivative of x^2")

    assert has_element?(view, "#desmos-surface")
    refute has_element?(view, "#geogebra-surface")

    view
    |> element("[data-testid='graph-tab-geogebra']")
    |> render_click()

    assert has_element?(view, "#geogebra-surface")
    refute has_element?(view, "#desmos-surface")
  end

  test "image upload runs through the native LiveView pipeline", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    upload =
      file_input(view, "#solve-form", :vision_input, [
        %{
          name: "whiteboard.png",
          content: png_fixture(),
          type: "image/png"
        }
      ])

    render_upload(upload, "whiteboard.png")
    assert render(view) =~ "Selected image: whiteboard.png"

    view
    |> element("#solve-form")
    |> render_submit(%{"prompt" => %{"input_query" => ""}})

    rendered = await_completed_render(view, "")

    assert has_element?(view, "#katex-output")
    assert has_element?(view, "#desmos-surface")
    assert rendered =~ "Pending verification" or rendered =~ "Analyze the uploaded image"
  end

  test "timed out requests surface an error without dropping the LiveView", %{conn: conn} do
    Application.put_env(:math_viz, :solve_timeout_ms, 25)

    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("#solve-form")
    |> render_submit(%{"prompt" => %{"input_query" => "hang forever"}})

    assert_receive {:solve_started, "hang forever", task_pid}
    ref = Process.monitor(task_pid)

    assert_receive {:DOWN, ^ref, :process, ^task_pid, :killed}

    rendered = sync_render(view)

    assert rendered =~ "Computation timed out. Try a simpler prompt or retry."
    assert has_element?(view, "[data-testid='status-label'][data-status='error']")
    assert render(view) =~ "hang forever"
  end

  test "a new submission cancels superseded work and preserves the latest result", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("#solve-form")
    |> render_submit(%{"prompt" => %{"input_query" => "hang forever"}})

    assert_receive {:solve_started, "hang forever", first_task_pid}
    first_ref = Process.monitor(first_task_pid)

    view
    |> element("#solve-form")
    |> render_submit(%{"prompt" => %{"input_query" => "What is an integral?"}})

    rendered = await_completed_render(view, "What is an integral?")

    assert_receive {:DOWN, ^first_ref, :process, ^first_task_pid, :killed}

    assert rendered =~ "What is an integral?"
    assert has_element?(view, "[data-testid='chat-output']")
    refute rendered =~ "Computation timed out."
    refute has_element?(view, "#desmos-surface")
  end

  test "strict NIM mode surfaces the routing error instead of the stub graph", %{conn: conn} do
    Application.put_env(:math_viz, :nlp_mode, :dual)
    Application.put_env(:math_viz, :nim_fallback_mode, :strict)

    Application.put_env(
      :math_viz,
      :nvidia_nim,
      Keyword.put(Application.get_env(:math_viz, :nvidia_nim, []), :api_key, nil)
    )

    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("#solve-form")
    |> render_submit(%{"prompt" => %{"input_query" => "What is an integral?"}})

    rendered = await_failed_render(view, "What is an integral?")

    assert rendered =~ "NIM is disabled: set NVIDIA_NIM_API_KEY."
    refute has_element?(view, "[data-testid='chat-output']")
    refute has_element?(view, "#desmos-surface")
  end

  defp await_completed_render(view, query) do
    assert_receive {:solve_started, ^query, task_pid}
    ref = Process.monitor(task_pid)
    assert_receive {:solve_finished, ^query, {:ok, _response}}
    assert_task_down(ref, task_pid, [:normal, :noproc])
    sync_render(view)
  end

  defp await_failed_render(view, query) do
    assert_receive {:solve_started, ^query, task_pid}
    ref = Process.monitor(task_pid)
    assert_receive {:solve_finished, ^query, {:error, _reason}}
    assert_task_down(ref, task_pid, [:normal, :noproc])
    sync_render(view)
  end

  defp sync_render(view) do
    _ = :sys.get_state(view.pid)
    render(view)
  end

  defp assert_task_down(ref, task_pid, reasons) do
    assert_receive {:DOWN, ^ref, :process, ^task_pid, reason}
    assert reason in reasons
  end

  defp restore_env(key, nil), do: Application.delete_env(:math_viz, key)
  defp restore_env(key, value), do: Application.put_env(:math_viz, key, value)

  defp png_fixture do
    Base.decode64!(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4////fwAJ+wP+X2VINQAAAABJRU5ErkJggg=="
    )
  end
end
