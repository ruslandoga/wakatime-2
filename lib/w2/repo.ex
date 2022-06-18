defmodule W2.Repo do
  use Ecto.Repo, otp_app: :w2, adapter: Ecto.Adapters.SQLite3
end
