defmodule MathVizWeb.SolveController do
  use MathVizWeb, :controller

  alias MathViz.Solve

  def create(conn, params) do
    case Solve.run(params) do
      {:ok, response} ->
        json(conn, MathViz.API.SolveResponse.to_map(response))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: errors_on(changeset)})

      {:error, reason} ->
        conn
        |> put_status(:bad_gateway)
        |> json(%{error: format_error(reason)})
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_atom(key), key) |> to_string()
      end)
    end)
  end

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)
end
