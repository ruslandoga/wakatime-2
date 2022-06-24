defmodule W2Web.DashboardLive.Index do
  use W2Web, :live_view
  alias W2.{Durations, Ingester}
  alias W2Web.DashboardView

  # fix highlight on selection

  # maybe just hide instead of filter + refetch
  # custom scroll animation
  # custom scroll indicator
  # fix unknowns
  # proper buckets
  # scroll to hovered branch / file / project

  @days 7

  @impl true
  def render(assigns) do
    assigns = assign(assigns, qs: qs(assigns, []))

    ~H"""
    <div class="h-screen w-full bg-red-100 font-mono overflow-hidden">
      <div class="h-1/2">
        <.bucket_timeline from={@from} to={@to} timeline={@timeline} />
      </div>
      <div class="h-1/2 flex">
        <div class="w-1/3 flex flex-col">
          <div class="bg-neutral-600 px-4 flex justify-between">
            <form class="inline-block text-blue-200" phx-change="date-range" phx-submit="date-range">
              <input type="date" id="from-date" name="from_date" value={@from} class="bg-neutral-600" phx-debounce="300"/>
              —
              <input type="date" id="to-date" name="to_date" value={@to} class="bg-neutral-600" phx-debounce="300"/>
            </form>
            <span class="text-white">Σ<%= format_time(@total) %></span>
          </div>
          <.projects_table
            total={@total}
            projects={@projects}
            project={@project}
            qs={@qs} />
        </div>
        <div class="w-1/3 flex flex-col"><.branches_table branches={@branches} qs={@qs}/></div>
        <div class="w-1/3 flex flex-col"><.files_table files={@files}/></div>
      </div>
    </div>
    """
  end

  # TODO div(...)
  defp bucket_timeline(assigns) do
    {from, to} = date_range(assigns)
    to = to |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
    from = from |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
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
    <svg id="timeline" phx-hook="RectHighlightHook" viewbox={"0 0 #{@h_count} #{@interval}"} preserveAspectRatio="none" class="h-full w-full bg-red-900">
    <%= for day_start <- @day_starts do %><.separator
      x={div(day_start, @interval) - @from_div} height={@interval}
    /><% end %><%= for rect <- @rects do %><.rect
      x={rect.x} y={rect.y} height={rect.height} color={color(rect.project)} project={rect[:project]} branch={rect[:branch]}
    /><% end %>
    </svg>
    """
  end

  defp separator(assigns) do
    ~H[<rect x={@x} y="0" width="1" height={@height} fill="#b91c1c80"/>]
  end

  defp rect(assigns) do
    ~H[<rect x={@x} y={@y} width="1" height={@height} fill={@color} data-project={@project} data-branch={@branch}/>]
  end

  defp branches_table(assigns) do
    ~H"""
    <div class="flex justify-between bg-red-400 px-4">
      <span>BRANCH</span>
      <span>TIME</span>
    </div>
    <ul id="branches-table" class="overflow-auto" phx-hook="BranchHighlightHook">
      <%= for [project, branch, total] <- @branches do %>
      <li class="px-4 flex justify-between leading-6 odd:bg-red-200 transition" data-project={project} data-branch={branch}>
        <span class="truncate"><span class="opacity-50"><%= project %>/</span><span><%= branch || "?unknown?" %></span></span>
        <span><%= format_time(total) %></span>
      </li>
      <% end %>
    </ul>
    """
  end

  defp files_table(assigns) do
    ~H"""
    <div class="flex justify-between bg-blue-400 px-4">
      <span>FILE</span>
      <span>TIME</span>
    </div>
      <ul id="files-table" class="overflow-auto" phx-hook="FileHighlightHook">
      <%= for [project, file, total] <- @files do %>
        <li class="px-4 flex justify-between leading-6 even:bg-blue-50 odd:bg-blue-100 transition" data-project={project} data-file={file}>
          <span class="truncate"><span class="opacity-50"><%= project %>/</span><span><%= file || "?unknown?" %></span></span>
          <span><%= format_time(total) %></span>
        </li>
      <% end %>
    </ul>
    """
  end

  defp projects_table(assigns) do
    ~H"""
    <div class="flex justify-between bg-black text-white px-4">
      <span>PROJECT</span>
      <span>TIME</span>
    </div>
    <ul id="projects-table" class="overflow-auto" phx-hook="ProjectHighlightHook">
      <%= for [project, total] <- @projects do %>
        <li data-project={project}>
          <%= live_patch to: Routes.dashboard_index_path(W2Web.Endpoint, :index, Keyword.put(@qs, :project, project)),
              style: "background-color:#{color(project)}",
              class: "px-4 flex justify-between leading-6 hover:font-bold transition" <> if(@project == project, do: " font-bold", else: "") do %>
            <span class="truncate"><%= project || "?unknown?" %></span>
            <span><%= format_time(total) %></span>
          <% end %>
        </li>
      <% end %>
    </ul>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(W2.PubSub, "heartbeats")
    end

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      socket
      |> assign(project: params["project"])
      |> assign(branch: params["branch"])
      |> assign(from: maybe_date(params["from"]))
      |> assign(to: maybe_date(params["to"]))
      |> fetch_data()

    {:noreply, socket}
  end

  defp maybe_date(value) do
    if value do
      case Date.from_iso8601(value) do
        {:ok, date} -> date
        _ -> nil
      end
    end
  end

  # TODO
  defp qs(assigns, overrides) do
    qs = []

    qs =
      if to = overrides[:to] || assigns[:to],
        do: Keyword.put(qs, :to, Date.to_iso8601(to)),
        else: qs

    qs =
      if from = overrides[:from] || assigns[:from],
        do: Keyword.put(qs, :from, Date.to_iso8601(from)),
        else: qs

    qs =
      if project = overrides[:project] || assigns[:project],
        do: Keyword.put(qs, :project, project),
        else: qs

    qs =
      if branch = overrides[:branch] || assigns[:branch],
        do: Keyword.put(qs, :branch, branch),
        else: qs

    qs
  end

  @impl true
  def handle_event("date-range", params, socket) do
    %{"from_date" => from, "to_date" => to} = params
    qs = qs(socket.assigns, from: maybe_date(from), to: maybe_date(to))
    path = Routes.dashboard_index_path(socket, :index, qs)
    {:noreply, push_patch(socket, to: path, replace: true)}
  end

  @impl true
  def handle_info({Ingester, :heartbeat}, socket) do
    {:noreply, fetch_data(socket)}
  end

  # TODO refresh from/to
  defp fetch_data(%{assigns: assigns} = socket) do
    {from, to} = date_range(assigns)
    project = assigns[:project]
    branch = assigns[:branch]

    timeline = Durations.fetch_timeline(project: project, from: from, to: to)
    projects = Durations.fetch_projects(from: from, to: to)

    total =
      if project do
        Enum.find_value(projects, fn [p, total] ->
          if p == project, do: total
        end) || 0
      else
        Enum.reduce(projects, 0, fn [_project, total], acc -> acc + total end)
      end

    branches = Durations.fetch_branches(project: project, from: from, to: to)

    files =
      Durations.fetch_files(project: project, branch: branch, from: from, to: to)
      |> Enum.map(fn
        [project, file, time] = og ->
          # TODO
          if file = file |> String.split("/") |> remove_file_project_prefix(project) do
            [project, Enum.join(file, "/"), time]
          else
            og
          end
      end)

    page_title = [project, branch, format_time(total)] |> Enum.reject(&is_nil/1) |> Enum.join(" ")

    socket
    |> assign(total: total)
    |> assign(projects: projects)
    |> assign(branches: branches)
    |> assign(files: files)
    |> assign(timeline: timeline)
    |> assign(page_title: page_title)
  end

  defp date_range(assigns) do
    to = naive(assigns[:to], :up) || NaiveDateTime.utc_now()
    from = naive(assigns[:from], :down) || add_days(to, -@days)
    {from, to}
  end

  defp naive(date, direction) do
    if date do
      time =
        case direction do
          :up -> ~T[23:59:59]
          :down -> ~T[00:00:00]
        end

      NaiveDateTime.new!(date, time)
    end
  end

  defp remove_file_project_prefix([project | rest], project), do: rest

  defp remove_file_project_prefix([_ | rest], project),
    do: remove_file_project_prefix(rest, project)

  defp remove_file_project_prefix([], _project), do: nil

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
