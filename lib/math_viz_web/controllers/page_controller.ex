defmodule MathVizWeb.PageController do
  use MathVizWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
