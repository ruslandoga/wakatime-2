defmodule W2.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use W2.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias W2.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import W2.DataCase
    end
  end

  setup tags do
    W2.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(W2.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  @default_heartbeat %{
    "branch" => "add-ingester",
    "category" => "coding",
    "cursorpos" => 1,
    "dependencies" => nil,
    "entity" => "/Users/q/Developer/copycat/w1/test/endpoint_test.exs",
    "is_write" => nil,
    "language" => "Elixir",
    "lineno" => 1,
    "lines" => 4,
    "project" => "w1",
    "time" => 1_653_576_917.486633,
    "type" => "file",
    "user_agent" =>
      "wakatime/v1.45.3 (darwin-21.4.0-arm64) go1.18.1 vscode/1.68.0-insider vscode-wakatime/18.1.5"
  }

  def heartbeat(overrides \\ %{}) do
    Map.merge(@default_heartbeat, overrides)
  end

  def unix(dt), do: DateTime.to_unix(dt)
  def msk(date, time), do: DateTime.new!(date, time, "Europe/Moscow")
  def tbs(date, time), do: DateTime.new!(date, time, "Asia/Tbilisi")
  def bkk(date, time), do: DateTime.new!(date, time, "Asia/Bangkok")
  def kul(date, time), do: DateTime.new!(date, time, "Asia/Kuala_Lumpur")

  def insert_heartbeats(overrides) do
    heartbeats = Enum.map(overrides, fn overrides -> heartbeat(overrides) end)
    W2.Ingester.insert_heartbeats(heartbeats, _machine_name = "mac3.local")
  end

  def parquet_heartbeats(tmp_dir, overrides) do
    heartbeats = Enum.map(overrides, fn overrides -> heartbeat(overrides) end)
    expected_count = length(heartbeats)
    parquet_path = Path.join(tmp_dir, "heartbeats.parquet")
    ndjson_path = Path.join(tmp_dir, "heartbeats.ndjson")
    ndjson = Enum.map_intersperse(heartbeats, "\n", &Jason.encode_to_iodata!/1)
    File.write!(ndjson_path, ndjson)

    [%{"Count" => ^expected_count}] =
      W2.duck_q(
        """
        copy (
          select * replace (to_timestamp(time)::timestamptz at time zone 'UTC' as time) from read_json($ndjson)
        ) to '#{parquet_path}' (
          format parquet, compression zstd, row_group_size 10000, parquet_version v2
        )
        """,
        %{"ndjson" => ndjson_path}
      )

    parquet_path
  end

  alias W2.Repo
  import Ecto.Query

  def all(schema) when is_atom(schema) do
    schema
    |> select([t], map(t, ^schema.__schema__(:fields)))
    |> Repo.all()
  end

  def all(table, fields) do
    table
    |> select([t], map(t, ^fields))
    |> Repo.all()
  end
end
