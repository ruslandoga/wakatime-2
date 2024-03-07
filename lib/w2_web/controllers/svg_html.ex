defmodule W2Web.SVGHTML do
  use W2Web, :html

  embed_templates "svg_html/*"

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

  # TODO
  defp color(project) do
    Enum.at(@colors, :erlang.phash2(project, @colors_count))
  end
end
