defmodule W2Web.DashboardLive.Index do
  use W2Web, :live_view
  alias W2.{Durations, Ingester}

  # hover
  # maybe just hide instead of filter + refetch
  # custom scroll animation
  # custom scroll indicator
  # fix unknowns
  # proper buckets
  # scroll to hovered branch / entity / project

  @days 7

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(W2.PubSub, "heartbeats")
    end

    {:ok, socket, temporary_assigns: [entities: [], branches: [], projects: [], timeline: []]}
  end

  @impl true
  def render(assigns) do
    {from, to} = local_date_range(assigns)

    %{
      project: selected_project,
      branch: selected_branch,
      entity: selected_entity,
      projects: projects,
      branches: branches,
      entities: entities
    } = assigns

    base_qs = qs(assigns, [])
    branch_qs = Keyword.delete(base_qs, :entity)
    project_qs = Keyword.delete(branch_qs, :branch)

    # TODO
    project_rows =
      Enum.map(projects, fn %{project: project} = row ->
        dimmed =
          if selected_project do
            selected_project != project
          end

        qs =
          if selected_project == project do
            Keyword.delete(project_qs, :project)
          else
            Keyword.put(project_qs, :project, project)
          end

        %{value: row, dimmed: dimmed, qs: qs}
      end)

    branch_rows =
      Enum.map(branches, fn %{project: project, branch: branch} = row ->
        dimmed =
          if selected_branch do
            selected_branch != branch
          end

        qs =
          if selected_branch == branch do
            Keyword.delete(branch_qs, :branch)
          else
            branch_qs |> Keyword.put(:project, project) |> Keyword.put(:branch, branch)
          end

        %{value: row, dimmed: dimmed, qs: qs}
      end)

    entity_rows =
      Enum.map(entities, fn %{project: project, entity: entity} = row ->
        dimmed =
          if selected_entity do
            selected_entity != entity
          end

        qs =
          if selected_entity == entity do
            Keyword.delete(base_qs, :entity)
          else
            base_qs
            |> Keyword.put(:project, project)
            |> Keyword.put(:entity, entity)
          end

        %{value: row, dimmed: dimmed, qs: qs}
      end)

    assigns =
      assign(assigns,
        project_rows: project_rows,
        branch_rows: branch_rows,
        entity_rows: entity_rows,
        from: DateTime.to_date(from),
        to: DateTime.to_date(to)
      )

    ~H"""
    <div class="h-screen w-full font-mono overflow-hidden">
      <div class="h-1/2">
        <.bucket_timeline from={@from} to={@to} timeline={@timeline} />
      </div>
      <div class="h-1/2 flex">
        <div class="w-1/3 flex flex-col">
          <div class="bg-neutral-600 px-4 flex justify-between">
            <form class="inline-block text-blue-200" phx-change="date-range" phx-submit="date-range">
              <input
                type="date"
                id="from-date"
                name="from_date"
                value={@from}
                class="bg-neutral-600 h-6"
                phx-debounce="300"
              /> —
              <input
                type="date"
                id="to-date"
                name="to_date"
                value={@to}
                class="bg-neutral-600 h-6"
                phx-debounce="300"
              />
            </form>
            <span class="text-white">Σ{format_time(@total)}</span>
          </div>
          <.time_table
            :let={
              %{
                value: %{project: project, category: category, duration: time},
                dimmed: dimmed,
                qs: qs
              }
            }
            rows={@project_rows}
            title="PROJECT"
            extra_header_class="bg-black text-white"
          >
            <.time_table_row
              style={"background-color:" <> color(project)}
              time={time}
              dimmed={dimmed}
              qs={qs}
            >
              <%= if prefix = project_prefix(category) do %>
                <.prefix_span prefix={prefix} value={project} />
              <% else %>
                {project}
              <% end %>
            </.time_table_row>
          </.time_table>
        </div>
        <div class="w-1/3 flex flex-col">
          <.time_table
            :let={
              %{value: %{project: project, branch: branch, duration: time}, dimmed: dimmed, qs: qs}
            }
            rows={@branch_rows}
            title="BRANCH"
            extra_header_class="bg-red-400"
          >
            <.time_table_row class="odd:bg-red-200" time={time} dimmed={dimmed} qs={qs}>
              <.prefix_span prefix={project} value={branch} />
            </.time_table_row>
          </.time_table>
        </div>
        <div class="w-1/3 flex flex-col bg-blue-50">
          <.time_table
            :let={
              %{value: %{project: project, entity: entity, duration: time}, dimmed: dimmed, qs: qs}
            }
            rows={@entity_rows}
            title="FILE"
            extra_header_class="bg-blue-400"
          >
            <.time_table_row class="odd:bg-blue-100" time={time} dimmed={dimmed} qs={qs}>
              <.prefix_span prefix={project} value={format_entity(entity)} />
            </.time_table_row>
          </.time_table>
        </div>
      </div>
    </div>
    """
  end

  # TODO div(...)
  defp bucket_timeline(assigns) do
    {from, to} = local_date_range(assigns)
    to = DateTime.to_unix(to)
    from = DateTime.to_unix(from)
    interval = Durations.interval(from, to)
    from_div = div(from, interval)

    rects =
      assigns.timeline
      |> W2Web.SVGHTML.bucket_timeline(interval)
      |> W2Web.SVGHTML.prepare_bucket_timeline_for_svg(from, interval)

    assigns =
      assign(assigns,
        interval: interval,
        rects: rects,
        midnights: Durations.midnights(from, to),
        from_div: from_div,
        h_count: div(to, interval) - div(from, interval) + 1
      )

    ~H"""
    <svg
      viewbox={"0 0 #{@h_count} #{@interval}"}
      preserveAspectRatio="none"
      class="h-full w-full bg-red-900"
    >
      <%= for midnight <- @midnights do %>
        <.separator x={div(midnight, @interval) - @from_div} height={@interval} />
      <% end %>
      <%= for rect <- @rects do %>
        <.rect x={rect.x} y={rect.y} height={rect.height} color={color(rect.project)} />
      <% end %>
    </svg>
    """
  end

  defp separator(assigns) do
    ~H[<rect x={@x} y="0" width="1" height={@height} fill="#b91c1c80" />]
  end

  defp rect(assigns) do
    ~H[<rect x={@x} y={@y} width="1" height={@height} fill={@color} />]
  end

  defp time_table(assigns) do
    ~H"""
    <div class={"flex justify-between px-4 " <> @extra_header_class}>
      <span>{@title}</span>
      <span>TIME</span>
    </div>
    <ul class="overflow-auto">
      <%= for row <- @rows do %>
        {render_slot(@inner_block, row)}
      <% end %>
    </ul>
    """
  end

  defp _link(assigns) do
    ~H"""
    <.link patch={@href} class="px-4 flex justify-between leading-6 transition">
      {render_slot(@inner_block)}
    </.link>
    """
  end

  defp time_table_row(%{dimmed: dimmed, qs: qs} = assigns) do
    assigns = assign_new(assigns, :class, fn -> "" end)
    assigns = assign_new(assigns, :style, fn -> nil end)
    class = if dimmed, do: assigns.class <> " opacity-20", else: assigns.class
    assigns = assign(assigns, class: class, path: ~p"/?#{qs}")

    ~H"""
    <li class={@class} style={@style}>
      <._link href={@path}>
        <span class="truncate">{render_slot(@inner_block)}</span><span>{format_time(@time)}</span>
      </._link>
    </li>
    """
  end

  defp prefix_span(assigns) do
    ~H"""
    <span class="opacity-50">{@prefix}/</span><span>{@value}</span>
    """
  end

  defp project_prefix("browsing"), do: "gh"
  defp project_prefix(_other), do: nil

  defp format_entity("https://github.com/" <> path) do
    case String.split(path, "/") do
      [_org, _repo, type, id] -> Path.join(type, id)
      _ -> format_entity(path)
    end
  end

  defp format_entity("https://" <> _rest = url) do
    %URI{host: host, path: path} = URI.parse(url)
    format_entity((host || "") <> (path || ""))
  end

  defp format_entity(file) do
    case String.split(file, "/", trim: true) do
      [] -> file
      [file] -> file
      [f1, f2] -> Path.join(f1, f2)
      [f1 | rest] -> Path.join([f1, "…", List.last(rest)])
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    from = maybe_date(params["from"])
    to = maybe_date(params["to"])

    socket =
      socket
      |> assign(project: params["project"])
      |> assign(branch: params["branch"])
      |> assign(entity: params["entity"])
      |> assign(category: params["category"])
      |> assign(type: params["type"])
      |> assign(editor: params["editor"])
      |> assign(interval: params["interval"])
      |> assign(from: from)
      |> assign(to: to)

    socket =
      if from && to && Date.after?(from, to) do
        qs = qs(socket.assigns, to: from)
        push_patch(socket, to: ~p"/?#{qs}", replace: true)
      else
        fetch_data(socket)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("date-range", params, socket) do
    %{"from_date" => from, "to_date" => to} = params
    qs = qs(socket.assigns, from: maybe_date(from), to: maybe_date(to))
    {:noreply, push_patch(socket, to: ~p"/?#{qs}", replace: true)}
  end

  @impl true
  def handle_info({Ingester, :heartbeat}, socket) do
    {:noreply, fetch_data(socket)}
  end

  # TODO refresh from/to
  defp fetch_data(%{assigns: assigns} = socket) do
    {from, to} = local_date_range(assigns)
    project = assigns[:project]
    branch = assigns[:branch]
    entity = assigns[:entity]
    category = assigns[:category]
    type = assigns[:type]
    editor = assigns[:editor]
    interval = assigns[:interval]

    timeline =
      Durations.fetch_timeline(
        project: project,
        category: category,
        type: type,
        editor: editor,
        branch: branch,
        entity: entity,
        from: from,
        to: to,
        interval: interval
      )

    projects =
      Durations.fetch_projects(
        from: from,
        to: to,
        category: category,
        type: type,
        editor: editor,
        interval: interval
      )

    total = Enum.reduce(projects, 0, fn %{duration: duration}, total -> total + duration end)

    branches =
      Durations.fetch_branches(
        project: project,
        from: from,
        to: to,
        interval: interval
      )

    entities =
      Durations.fetch_entities(
        project: project,
        category: category,
        type: type,
        editor: editor,
        branch: branch,
        from: from,
        to: to,
        interval: interval
      )
      |> Enum.map(fn
        %{project: project, entity: entity} = og ->
          # TODO
          if entity = entity |> String.split("/") |> remove_file_project_prefix(project) do
            Map.replace!(og, :entity, Enum.join(entity, "/"))
          else
            og
          end
      end)

    page_title = format_time(total)

    socket
    |> assign(total: total)
    |> assign(projects: projects)
    |> assign(branches: branches)
    |> assign(entities: entities)
    |> assign(timeline: timeline)
    |> assign(page_title: page_title)
  end

  defp local_date_range(assigns) do
    to = local_datetime(assigns[:to], :up) || Durations.to_local()
    from = local_datetime(assigns[:from], :down) || add_days(to, -@days)
    {from, to}
  end

  defp local_datetime(date, direction) do
    if date do
      time =
        case direction do
          :up -> ~T[23:59:59]
          :down -> ~T[00:00:00]
        end

      DateTime.new!(date, time, Durations.local_tz(date))
    end
  end

  defp remove_file_project_prefix([project | rest], project), do: rest

  defp remove_file_project_prefix([_ | rest], project) do
    remove_file_project_prefix(rest, project)
  end

  defp remove_file_project_prefix([], _project), do: nil

  defp color(project) do
    hue = :erlang.phash2(project, 360)
    "hsl(#{hue},40%,50%)"
  end

  # TODO make add_days take relocations into account
  @spec add_days(DateTime.t(), integer) :: DateTime.t()
  defp add_days(dt, days) do
    time = Time.new!(dt.hour, dt.minute, dt.second)

    Date.new!(dt.year, dt.month, dt.day)
    |> Date.add(days)
    |> DateTime.new!(time, dt.time_zone)
  end

  defp format_time(seconds) do
    seconds = round(seconds)
    hours = String.pad_leading(to_string(div(seconds, 3600)), 2, "0")
    rem = rem(seconds, 3600)
    minutes = String.pad_leading(to_string(div(rem, 60)), 2, "0")
    seconds = String.pad_leading(to_string(rem(rem, 60)), 2, "0")
    hours <> ":" <> minutes <> ":" <> seconds
  end

  defp maybe_date(value) do
    if value do
      case Date.from_iso8601(value) do
        {:ok, date} -> date
        _ -> nil
      end
    end
  end

  defp qs(assigns, overrides) do
    []
    |> maybe_put_qs(assigns, overrides, :to, &Date.to_iso8601/1)
    |> maybe_put_qs(assigns, overrides, :from, &Date.to_iso8601/1)
    |> maybe_put_qs(assigns, overrides, :project)
    |> maybe_put_qs(assigns, overrides, :branch)
    |> maybe_put_qs(assigns, overrides, :entity)
    |> maybe_put_qs(assigns, overrides, :category)
    |> maybe_put_qs(assigns, overrides, :interval)
    |> maybe_put_qs(assigns, overrides, :type)
    |> maybe_put_qs(assigns, overrides, :editor)
  end

  defp maybe_put_qs(qs, assigns, overrides, field, transform \\ &Function.identity/1) do
    if value = overrides[field] || assigns[field] do
      Keyword.put(qs, field, transform.(value))
    else
      qs
    end
  end
end
