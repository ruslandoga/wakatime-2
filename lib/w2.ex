defmodule W2 do
  @moduledoc """
  W2 keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @app :w2

  def api_key do
    Application.fetch_env!(@app, :api_key)
  end

  def dashboard_auth_opts do
    Application.fetch_env!(@app, :dashboard)
  end

  def interval do
    Application.fetch_env!(@app, :interval)
  end
end
