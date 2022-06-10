defmodule W2Web.DashboardLive.Index do
  use W2Web, :live_view
  alias W2.{Durations, Ingester}

  @days 7

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen w-full bg-red-100 flex flex-col md:flex-row font-mono">
      <div class="md:w-1/2 lg:w-3/4 bg-red-200 flex flex-col order-2 md:order-1">
        <div class="px-4 pt-4 pb-2 h-64 md:flex-grow">
          <.svg_chart from={@from} to={@to} buckets={@buckets} />
        </div>
        <div class="px-4 pb-4 pt-2">
          <.timeline from={@from} to={@to} timeline={@timeline} />
        </div>
      </div>
      <div class="md:w-1/2 lg:w-1/4 bg-red-300 order-1 md:order-2">
        <div class="p-4 font-semibold ">
          Total <%= format_time(@total) %>
        </div>
        <div class="px-4 pb-4">
          <.table projects={@projects} />
        </div>
      </div>
    </div>
    """
  end

  # TODO div(...)
  defp svg_chart(assigns) do
    to = DateTime.from_naive!(assigns.to || NaiveDateTime.utc_now(), "Etc/UTC")
    from = DateTime.from_naive!(assigns.from || add_days(to, -@days), "Etc/UTC")
    to = DateTime.to_unix(to)
    from = DateTime.to_unix(from)
    from_div = div(from, 3600)
    interval = Durations.interval(from, to)
    bars = W2Web.DashboardView.prepare_chart_for_svg(from, interval, assigns.buckets)

    assigns =
      assign(assigns,
        interval: interval,
        bars: bars,
        day_starts: Durations.day_starts(from, to),
        from_div: from_div
      )

    ~H"""
    <svg viewbox={"0 0 169 #{@interval}"} preserveAspectRatio="none" class="h-full w-full bg-red-900">
    <%= for day_start <- @day_starts do %><.rect
      x={div(day_start, @interval) - @from_div} y="0" width="1" height={@interval} color="#b91c1c80"
    /><% end %><%= for bar <- @bars do %><.rect
      x={bar.x} y={bar.y} width="1" height={bar.height} color={color(bar.project)}
    /><% end %>
    </svg>
    """
  end

  defp rect(assigns) do
    ~H[<rect x={@x} y={@y} width={@width} height={@height} fill={@color} />]
  end

  defp timeline(assigns) do
    to = DateTime.from_naive!(assigns.to || NaiveDateTime.utc_now(), "Etc/UTC")
    from = DateTime.from_naive!(assigns.from || add_days(to, -@days), "Etc/UTC")
    to = DateTime.to_unix(to)
    from = DateTime.to_unix(from)
    interval = Durations.interval(from, to)
    from = div(from, interval) * 3600
    to = (div(to, interval) + 1) * 3600
    range = to - from
    assigns = assign(assigns, range: range, from: from, to: to)

    # TODO
    ~H"""
    <svg viewbox="0 0 200 1" preserveAspectRatio="none" class="bg-red-800 h-6 w-full">
      <%= for [project, from, to] <- @timeline do %><.rect
        x={"#{Float.round((from - @from) / @range * 100, 2)}%"}
        y="0"
        width={"#{Float.round((to - from) / @range * 100, 2)}%"}
        height="1"
        color={color(project)}
      /><% end %>
    </svg>
    """
  end

  defp table(assigns) do
    ~H"""
    <table class="border w-full border-red-700">
      <thead class="border border-red-700">
        <th class="px-1 text-left">project</th>
        <th class="px-1 text-left">time</th>
      </thead>
      <tbody class="divide-y divide-red-700">
        <%= for {project, total} <- @projects do %><.table_row
          project={project}
          color={color(project)}
          total={total}
        /><% end %>
      </tbody>
    </table>
    """
  end

  defp table_row(assigns) do
    ~H"""
    <tr style={"background-color:#{@color}"}>
      <td class={"px-1 leading-8 font-medium hover:opacity-50 cursor-pointer text-ellipsis"}><%= @project %></td>
      <td class="font-medium"><%= format_time(@total) %></td>
    </tr>
    """
  end

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
    from = DateTime.from_naive!(socket.assigns.from || add_days(to, -@days), "Etc/UTC")

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

  # TODO
  @colors [
    "#fbbf24",
    "#4ade80",
    "#06b6d4",
    "#f87171",
    "#60a5fa",
    "#facc15",
    "#ec4899",
    "#0284c7",
    "#a3a3a3"
  ]

  @colors_count length(@colors)

  defp color(project) do
    Enum.at(@colors, :erlang.phash2(project, @colors_count))
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
