defmodule W2Web.DashboardLive.Index do
  use W2Web, :live_view
  alias W2.Durations

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen w-full bg-red-100 flex">
      <div class="w-3/4 bg-red-200 flex flex-col">
        <div id="bucket-container" class="p-4 bg-blue-100 h-1/2" phx-update="ignore">
          <div id="bucket" phx-hook="BarChart" class="h-full"></div>
        </div>
        <div>timeline</div>
      </div>
      <div class="w-1/4 bg-red-300">
        <div class="p-4">
          Total <%= format_time(@total) %>
        </div>
        <div class="p-4">
          <h3>Projects</h3>
          <table class="border w-full">
            <thead class="border divide-x">
              <th class="px-1 text-left">project</th>
              <th class="px-1 text-left">time</th>
            </thead>
            <tbody class="divide-y">
              <%= for {project, total} <- @projects do %>
                <tr>
                  <td class="px-1"><%= project %></td>
                  <td><%= format_time(total) %></td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, from: nil, to: nil)}
  end

  @impl true
  def handle_params(%{"from" => from, "to" => to}, _uri, socket) do
    with {:ok, from} <- NaiveDateTime.from_iso8601(from),
         {:ok, to} <- NaiveDateTime.from_iso8601(to) do
      {:noreply, socket |> assign(from: from, to: to) |> fetch_data()}
    else
      _ -> {:noreply, push_patch(socket, "/")}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket |> assign(from: nil, to: nil) |> fetch_data()}
  end

  defp fetch_data(socket) do
    to = DateTime.from_naive!(socket.assigns.to || NaiveDateTime.utc_now(), "Etc/UTC")
    from = DateTime.from_naive!(socket.assigns.from || week_ago(to), "Etc/UTC")

    bucket_data = Durations.bucket_data(from, to)
    total_data = Durations.total_data(from, to)
    projects_data = Durations.projects_data(from, to)
    timeline_data = Durations.timeline_data(from, to)

    socket
    |> assign(total: total_data)
    |> assign(projects: projects_data)
    |> push_event("bucket", %{"data" => bucket_data})
    |> push_event("timeline", %{"data" => timeline_data})
  end

  @spec week_ago(NaiveDateTime.t()) :: NaiveDateTime.t()
  defp week_ago(naive) do
    time = Time.new!(naive.hour, naive.minute, naive.second)

    Date.new!(naive.year, naive.month, naive.day)
    |> Date.add(-7)
    |> NaiveDateTime.new!(time)
  end

  defp format_time(seconds) do
    hours = String.pad_leading(to_string(div(seconds, 3600)), 2, "0")
    rem = rem(seconds, 3600)
    minutes = String.pad_leading(to_string(div(rem, 60)), 2, "0")
    seconds = String.pad_leading(to_string(rem(rem, 60)), 2, "0")
    hours <> ":" <> minutes <> ":" <> seconds
  end
end
