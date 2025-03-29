defmodule W2 do
  @moduledoc """
  W2 keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @app :w2

  def api_key do
    Application.fetch_env!(@app, :api_key)
  end

  def interval do
    Application.fetch_env!(@app, :interval)
  end

  # TODO
  def parquet do
    "heartbeats.parquet.zst"
  end

  def duck do
    :persistent_term.get(:duck)
  end

  def duck_q(sql) do
    duck_q(duck(), sql, %{})
  end

  def duck_q(sql, params) do
    duck_q(duck(), sql, params)
  end

  def duck_q(conn, sql, params) do
    stmt = DuxDB.prepare(conn, sql)

    try do
      duck_bind(stmt, params)
      duck_execute(stmt)
    after
      DuxDB.destroy_prepare(stmt)
    end
  end

  defp duck_bind(stmt, params) do
    Enum.each(params, fn {k, v} ->
      idx = DuxDB.bind_parameter_index(stmt, k)

      cond do
        is_integer(v) -> DuxDB.bind_int64(stmt, idx, v)
        is_float(v) -> DuxDB.bind_double(stmt, idx, v)
        is_binary(v) -> DuxDB.bind_varchar(stmt, idx, v)
        is_boolean(v) -> DuxDB.bind_boolean(stmt, idx, v)
        is_struct(v, Date) -> DuxDB.bind_date(stmt, idx, v)
        is_struct(v, Time) -> DuxDB.bind_time(stmt, idx, v)
        is_struct(v, DateTime) -> DuxDB.bind_timestamp(stmt, idx, v)
        is_struct(v, Duration) -> DuxDB.bind_interval(stmt, idx, v)
        is_nil(v) -> DuxDB.bind_null(stmt, idx)
        true -> raise ArgumentError, "Unsupported type: #{inspect(v)}"
      end
    end)
  end

  defp duck_execute(stmt) do
    result = DuxDB.execute_prepared_dirty_io(stmt)

    try do
      chunks = duck_fetch_chunks(result)
      duck_chunks_to_rows(chunks, _acc = [])
    after
      DuxDB.destroy_result(result)
    end
  end

  defp duck_fetch_chunks(result) do
    case DuxDB.fetch_chunk(result) do
      chunk when is_reference(chunk) ->
        vectors =
          try do
            duck_fetch_vectors(result, chunk)
          after
            DuxDB.destroy_data_chunk(chunk)
          end

        [vectors | duck_fetch_chunks(result)]

      nil ->
        []
    end
  end

  defp duck_fetch_vectors(result, chunk) do
    Map.new(0..(DuxDB.column_count(result) - 1), fn i ->
      {DuxDB.column_name(result, i), DuxDB.data_chunk_get_vector(chunk, i)}
    end)
  end

  defp duck_chunks_to_rows([chunk | chunks], acc) do
    {k, vec} = {Map.keys(chunk), Map.values(chunk)}

    acc =
      Enum.reduce(Enum.zip(vec), acc, fn v, acc ->
        [Map.new(Enum.zip(k, Tuple.to_list(v))) | acc]
      end)

    duck_chunks_to_rows(chunks, acc)
  end

  defp duck_chunks_to_rows([], acc), do: :lists.reverse(acc)
end
