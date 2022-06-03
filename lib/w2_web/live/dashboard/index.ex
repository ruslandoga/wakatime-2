defmodule W2Web.DashboardLive.Index do
  use W2Web, :live_view
  alias W2.{Durations, Ingester}

  # <span class="transform:rotate(-90deg);transform-origin: bottom left;">
  #               <%= DateTime.from_unix!(time) %> <%= Jason.encode!(totals) %>
  #             </span>

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen w-full bg-red-100 flex flex-col md:flex-row font-mono">
      <div class="md:w-1/2 lg:w-3/4 bg-red-200 flex flex-col order-2 md:order-1">
        <div class="px-4 pt-4 pb-2 h-64 md:h-1/2">
          <div class="relative h-full bg-red-900">
            <%# buckets: <%= Jason.encode!(@buckets) %>
            <%
              to = DateTime.from_naive!(@to || NaiveDateTime.utc_now(), "Etc/UTC")
              from = DateTime.from_naive!(@from || add_days(to, -4), "Etc/UTC")
              to = DateTime.to_unix(to)
              from = DateTime.to_unix(from)
              interval = Durations.interval(from, to)
              range = to - from + interval
              width = interval / range
            %>
            <%= for [time, totals] <- @buckets do %>
              <% height = Enum.reduce(totals, 0, fn {_project, total}, acc -> acc + total end) %>
              <div class="absolute bg-red-400" style={"bottom:0;left:#{(time - from) / range * 100}%;width:#{width * 100}%;height:#{height / interval * 100}%;"}></div>
            <% end %>
          </div>
        </div>
        <div class="px-4 pb-4 pt-2 md:h-1/2">
          <div class="relative bg-red-800 h-full">
          <%# timeline: <%= Jason.encode!(@timeline) %>
          <%
            to = DateTime.from_naive!(@to || NaiveDateTime.utc_now(), "Etc/UTC")
            from = DateTime.from_naive!(@from || add_days(to, -4), "Etc/UTC")
            to = DateTime.to_unix(to)
            from = DateTime.to_unix(from)
            interval = Durations.interval(from, to)
            range = to - from + interval
          %>

          <%= for {project, durations} <- @timeline do %>
            <div class="relative h-6">
              <%= project %>
              <%= for [duration_from, duration_to] <- durations do %>
                <div class="absolute bg-red-200 h-full" style={"top:0;left:#{(duration_from-from)/range*100}%;width:#{(duration_to-duration_from)/range*100}%;"}></div>
              <% end %>
            </div>
          <% end %>
          </div>
        </div>
      </div>
      <div class="md:w-1/2 lg:w-1/4 bg-red-300 order-1 md:order-2">
        <div class="p-4 font-semibold ">
          Total <%= format_time(@total) %>
        </div>
        <div class="px-4 pb-4">
          <table class="border w-full border-red-700">
            <thead class="border border-red-700">
              <th class="px-1 text-left">project</th>
              <th class="px-1 text-left">time</th>
            </thead>
            <tbody class="divide-y divide-red-700">
              <%= for {project, total} <- @projects do %>
                <tr>
                  <td class="px-1 font-medium hover:text-red-500 cursor-pointer text-ellipsis"><%= project %></td>
                  <td class="font-medium"><%= format_time(total) %></td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  # defp color(project) do
  # end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(W2.PubSub, "heartbeats")
    end

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

  @impl true
  def handle_info({Ingester, :heartbeat}, socket) do
    {:noreply, fetch_data(socket)}
  end

  defp fetch_data(socket) do
    to = DateTime.from_naive!(socket.assigns.to || NaiveDateTime.utc_now(), "Etc/UTC")
    from = DateTime.from_naive!(socket.assigns.from || add_days(to, -4), "Etc/UTC")

    bucket_data = Durations.bucket_data(from, to)
    total_data = Durations.total_data(from, to)

    projects_data =
      Durations.projects_data(from, to)
      # TODO
      |> Enum.sort_by(fn {_project, time} -> time end, :desc)

    timeline_data = Durations.timeline_data(from, to)

    socket
    |> assign(total: total_data)
    |> assign(projects: projects_data)
    |> assign(buckets: bucket_data)
    # |> push_event("bucket", %{"data" => bucket_data})
    # |> push_event("timeline", %{"data" => timeline_data})
    |> assign(timeline: timeline_data)
  end

  @spec add_days(NaiveDateTime.t(), integer) :: NaiveDateTime.t()
  defp add_days(naive, days) do
    time = Time.new!(naive.hour, naive.minute, naive.second)

    Date.new!(naive.year, naive.month, naive.day)
    |> Date.add(days)
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
