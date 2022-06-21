defmodule W2Web.DashboardLive.Index do
  use W2Web, :live_view
  alias W2.{Durations, Ingester}
  alias W2Web.DashboardView

  @days 7

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen w-full bg-red-100 flex flex-col md:flex-row font-mono">
      <div class="md:w-1/2 lg:w-3/4 bg-red-200 flex flex-col order-2 md:order-1">
        <div class="p-4 h-64 md:flex-grow">
          <.bucket_timeline from={@from} to={@to} timeline={@timeline} />
        </div>
      </div>
      <div class="md:w-1/2 lg:w-1/4 bg-red-300 order-1 md:order-2">
        <form class="p-4 inline-block" phx-change="date-range" phx-submit="date-range">
          <input type="date" id="from-date" name="from_date" value={@from_date} class="px-1 bg-pink-200 text-blue-600" phx-debounce="300"/>
          <input type="time" id="from-time" name="from_time" value={@from_time} class="px-1 bg-pink-200 text-blue-600" phx-debounce="300"/>
          --
          <input type="date" id="to-date" name="to_date" value={@to_date} class="px-1 bg-pink-200 text-blue-600" phx-debounce="300"/>
          <input type="time" id="to-time" name="to_time" value={@to_time} class="px-1 bg-pink-200 text-blue-600" phx-debounce="300"/>
        </form>
        <div class="px-4 pb-4 font-semibold ">
          <span>Total <%= format_time(@total) %></span>
        </div>
        <div class="px-4 pb-4">
          <.table projects={@projects} />
        </div>
      </div>
    </div>
    """
  end

  # TODO div(...)
  defp bucket_timeline(assigns) do
    to = DateTime.from_naive!(assigns.to || NaiveDateTime.utc_now(), "Etc/UTC")
    from = DateTime.from_naive!(assigns.from || add_days(to, -@days), "Etc/UTC")
    to = DateTime.to_unix(to)
    from = DateTime.to_unix(from)
    interval = Durations.interval(from, to)
    from_div = div(from, interval)

    rects =
      assigns.timeline
      |> DashboardView.bucket_timeline(interval)
      |> DashboardView.prepare_bucket_timeline_for_svg(from, interval)

    assigns =
      assign(assigns,
        interval: interval,
        rects: rects,
        day_starts: Durations.day_starts(from, to),
        from_div: from_div,
        h_count: div(to, interval) - div(from, interval) + 1
      )

    ~H"""
    <svg viewbox={"0 0 #{@h_count} #{@interval}"} preserveAspectRatio="none" class="h-full w-full bg-red-900">
    <%= for day_start <- @day_starts do %><.rect
      x={div(day_start, @interval) - @from_div} y="0" width="1" height={@interval} color="#b91c1c80"
    /><% end %><%= for rect <- @rects do %><.rect
      x={rect.x} y={rect.y} width="1" height={rect.height} color={color(rect.project)}
    /><% end %>
    </svg>
    """
  end

  defp rect(assigns) do
    ~H[<rect x={@x} y={@y} width={@width} height={@height} fill={@color} />]
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

    {:ok, reset_date_range(socket)}
  end

  @impl true
  def handle_params(%{"from" => from, "to" => to}, _uri, socket) do
    with {:ok, from} <- parse_from(from), {:ok, to} <- parse_to(to) do
      {:noreply, socket |> set_date_range(from, to) |> fetch_data()}
    else
      _ -> {:noreply, push_patch(socket, to: "/", replace: true)}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket |> reset_date_range() |> fetch_data()}
  end

  @impl true
  def handle_event("date-range", params, socket) do
    # TODO validate
    %{
      "from_date" => from_date,
      "to_date" => to_date,
      "from_time" => from_time,
      "to_time" => to_time
    } = params

    from = parse_date_time(from_date, from_time)
    to = parse_date_time(to_date, to_time)

    path =
      Routes.dashboard_index_path(socket, :index,
        from: NaiveDateTime.to_iso8601(from),
        to: NaiveDateTime.to_iso8601(to)
      )

    {:noreply, push_patch(socket, to: path, replace: true)}
  end

  defp parse_date_time(date, time) do
    case {Date.from_iso8601(date), Time.from_iso8601(time)} do
      {{:ok, date}, {:ok, time}} -> NaiveDateTime.new!(date, time)
      {{:ok, date}, _} -> NaiveDateTime.new!(date, Time.new!(0, 0, 0))
      _ -> nil
    end
  end

  @impl true
  def handle_info({Ingester, :heartbeat}, socket) do
    {:noreply, fetch_data(socket)}
  end

  # TODO refresh from/to
  defp fetch_data(socket) do
    to = DateTime.from_naive!(socket.assigns.to || NaiveDateTime.utc_now(), "Etc/UTC")
    from = DateTime.from_naive!(socket.assigns.from || add_days(to, -@days), "Etc/UTC")

    %{total: total, projects: projects, timeline: timeline} =
      Durations.fetch_dashboard_data(from, to)

    # TODO
    projects = Enum.sort_by(projects, fn {_project, time} -> time end, :desc)

    socket
    |> assign(total: total)
    |> assign(projects: projects)
    |> assign(timeline: timeline)
    |> assign(page_title: format_time(total))
  end

  defp reset_date_range(socket) do
    to = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
    from = add_days(to, -@days)
    set_date_range(socket, from, to)
  end

  defp set_date_range(socket, from, to) do
    assign(socket,
      from: from,
      to: to,
      from_date: NaiveDateTime.to_date(from),
      from_time: NaiveDateTime.to_time(from),
      to_date: NaiveDateTime.to_date(to),
      to_time: NaiveDateTime.to_time(to)
    )
  end

  defp parse_from(value) do
    NaiveDateTime.from_iso8601(value)
  end

  defp parse_to(value) do
    NaiveDateTime.from_iso8601(value)
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
    seconds = round(seconds)
    hours = String.pad_leading(to_string(div(seconds, 3600)), 2, "0")
    rem = rem(seconds, 3600)
    minutes = String.pad_leading(to_string(div(rem, 60)), 2, "0")
    seconds = String.pad_leading(to_string(rem(rem, 60)), 2, "0")
    hours <> ":" <> minutes <> ":" <> seconds
  end
end
