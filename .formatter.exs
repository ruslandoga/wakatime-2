[
  import_deps: [:ecto, :plug],
  inputs: ["*.{ex,exs}", "priv/*/seeds.exs", "{config,lib,test,bench,dev}/**/*.{ex,exs}"],
  subdirectories: ["priv/*/migrations"]
]
