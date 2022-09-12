defmodule W2Web.DashboardLive.Timer do
  use W2Web, :live_view
  alias W2.Timers

  @impl true
  def mount(_session, _params, socket) do
    {:ok, fetch_timers(socket), temporary_assigns: [timers: []]}
  end

  # TODO finish form
  # TODO show timers as backdrop on main dashboard
  # TODO delete timer?

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex items-center justify-center min-h-screen">
      <div>
      <%= for timer <- @timers do %>
        <div><%= timer.started_at %></div>
      <% end %>
      </div>

      <.form let={f} for={@changeset} phx-submit="form-submit" phx-update="form-update">
        <div>
          <label>
            <div>Task</div>
            <%= text_input f, :task, placeholder: "Come up with a name ...", class: "border rounded p-1", phx_debounce: "blur" %>
          </label>
          <%= error_tag f, :task %>
        </div>

        <%= submit "Start" %>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, update_changeset(socket)}
  end

  @impl true
  def handle_event("form-submit", %{"timer" => params}, socket) do
    case Timers.create_timer(params) do
      {:ok, _timer} ->
        {:noreply, socket |> fetch_timers() |> update_changeset()}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def handle_event("form-update", %{"timer" => params}, socket) do
    {:noreply, update_changeset(socket, params)}
  end

  defp fetch_timers(socket) do
    assign(socket, timers: Timers.list_active_timers())
  end

  defp update_changeset(socket, params \\ %{}) do
    assign(socket, changeset: Timers.timer_changeset(params))
  end
end
