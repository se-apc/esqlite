defmodule Esqlite3 do
  @moduledoc """
  Use a Sqlite3 database in Elixir _and_ Erlang!
  """
  require Logger
  @default_timeout Application.get_env(:esqlite, :default_timeout, 5000)

  @typep error_tup2 :: {:error, term}

  @typedoc "Connection record."
  @type connection :: {:connection, reference, Esqlite3Nif.connection()}

  @typedoc "Statement record."
  @type prepared_statement :: {:statement, Esqlite3Nif.statement(), connection}

  @typedoc "File to open."
  @type filename :: Path.t() | iodata

  @typedoc "SQL binary or charlist."
  @type sql :: iodata

  @doc "Opens a sqlite3 database mentioned in filename."
  @spec open(filename) :: {:ok, connection} | error_tup2
  def open(filename), do: open(filename, {:readwrite, :create}, @default_timeout)

  @doc "Opens a sqlite3 database mentioned in filename with flags."
  def open(filename, flags) when is_tuple(flags), do: open(filename, flags, @default_timeout)

  @doc "Opens a sqlite3 database with a flags tuple and a timeout."
  @spec open(filename, tuple, timeout) :: {:ok, connection} | error_tup2
  def open(filename, flags, timeout) when is_tuple(flags) do
    filename = to_charlist(filename)

    with {:ok, connection} <- Esqlite3Nif.start(),
         ref when is_reference(ref) <- make_ref(),
         :ok <- Esqlite3Nif.open(connection, ref, self(), filename, flags),
         :ok <- receive_answer(ref, timeout) do
      {:ok, {:connection, make_ref(), connection}}
    else
      {:error, _} = err -> err
    end
  end

  @doc "Execute sql statement, returns the number of affected rows."
  @spec exec(sql, connection) :: :ok | error_tup2
  def exec(sql, connection), do: exec(sql, connection, @default_timeout)

  @doc "Execute sql statement, returns the number of affected rows."
  @spec exec(sql, connection, timeout) :: :ok | error_tup2
  def exec(sql, connection, timeout)

  def exec(sql, {:connection, _ref, connection}, timeout) do
    ref = make_ref()
    :ok = Esqlite3Nif.exec(connection, ref, self(), sql)
    receive_answer(ref, timeout)
  end

  @doc "Execute SQL statement and bind params to it."
  @spec exec(sql, Esqlite3Nif.bind_args(), connection) :: :ok | error_tup2
  def exec(sql, params, connection), do: exec(sql, params, connection, @default_timeout)

  @doc "Execute SQL statement and bind params to it."
  @spec exec(sql, Esqlite3Nif.bind_args(), connection, timeout) :: :ok | error_tup2
  def exec(sql, params, connection, timeout) when is_list(params) do
    {:ok, statement} = prepare(sql, connection, timeout)
    :ok = bind(statement, params)
    step(statement, timeout)
  end

  @doc "Return the number of affected rows of last statement."
  @spec changes(connection) :: integer | error_tup2
  def changes(connection), do: changes(connection, @default_timeout)

  @doc "Return the number of affected rows of last statement."
  @spec changes(connection, timeout) :: {:ok, integer} | error_tup2
  def changes(connection, timeout)

  def changes({:connection, _ref, connection}, timeout) do
    ref = make_ref()
    :ok = Esqlite3Nif.changes(connection, ref, self())
    receive_answer(ref, timeout)
  end

  @doc "Insert records, returns the last rowid."
  @spec insert(sql, connection) :: {:ok, integer} | error_tup2
  def insert(sql, connection), do: insert(sql, connection, @default_timeout)

  @doc "Insert records, returns the last rowid."
  @spec insert(sql, connection, timeout) :: {:ok, integer} | error_tup2
  def insert(sql, connection, timeout)

  def insert(sql, {:connection, _ref, connection}, timeout) do
    ref = make_ref()
    :ok = Esqlite3Nif.insert(connection, ref, self(), sql)
    receive_answer(ref, timeout)
  end

  @doc "Prepare a statement"
  @spec prepare(sql, connection) :: {:ok, prepared_statement} | error_tup2
  def prepare(sql, connection), do: prepare(sql, connection, @default_timeout)

  @doc "Prepare a statement"
  @spec prepare(sql, connection, timeout) :: {:ok, prepared_statement} | error_tup2
  def prepare(sql, connection, timeout)

  def prepare(sql, {:connection, _ref, connection} = c, timeout) do
    ref = make_ref()
    :ok = Esqlite3Nif.prepare(connection, ref, self(), sql)

    case receive_answer(ref, timeout) do
      {:ok, prepared_statement} -> {:ok, {:statement, prepared_statement, c}}
      err -> err
    end
  end

  @doc "Step into a prepared statement."
  def step(prepared_statement), do: step(prepared_statement, @default_timeout)

  @doc "Step into a prepared statement."
  @spec step(prepared_statement, timeout) :: :"$busy" | :"$done" | {:row, any} | error_tup2
  def step(prepared_statement, timeout)

  def step({:statement, prepared_statement, {:connection, _ref, connection}}, timeout) do
    ref = make_ref()
    :ok = Esqlite3Nif.step(connection, prepared_statement, ref, self())
    receive_answer(ref, timeout)
  end

  @doc "Reset the prepared statement back to its initial state."
  @spec reset(prepared_statement) :: :ok | error_tup2
  def reset(prepared_statement), do: reset(prepared_statement, @default_timeout)

  @doc "Reset the prepared statement back to its initial state."
  @spec reset(prepared_statement, timeout) :: :ok | error_tup2
  def reset(prepared_statement, timeout)

  def reset({:statement, prepared_statement, {:connection, _ref, connection}}, timeout) do
    ref = make_ref()
    :ok = Esqlite3Nif.reset(connection, prepared_statement, ref, self())
    receive_answer(ref, timeout)
  end

  @doc "Bind values to prepared statements"
  @spec bind(prepared_statement, Esqlite3Nif.bind_args()) :: :ok | error_tup2
  def bind(prepared_statement, args), do: bind(prepared_statement, args, @default_timeout)

  @doc "Bind values to prepared statements"
  @spec bind(prepared_statement, Esqlite3Nif.bind_args(), timeout) :: :ok | error_tup2
  def bind(prepared_statement, args, timeout)

  def bind({:statement, prepared_statement, {:connection, _ref, connection}}, args, timeout) do
    ref = make_ref()
    :ok = Esqlite3Nif.bind(connection, prepared_statement, ref, self(), args)
    receive_answer(ref, timeout)
  end

  @doc "Return the column names of the prepared statement."
  @spec column_names(prepared_statement) :: tuple | error_tup2
  def column_names(prepared_statement), do: column_names(prepared_statement, @default_timeout)

  @doc "Return the column names of the prepared statement."
  @spec column_names(prepared_statement, timeout) :: tuple | error_tup2
  def column_names(prepared_statement, timeout)

  def column_names({:statement, prepared_statement, {:connection, _ref, connection}}, timeout) do
    ref = make_ref()
    :ok = Esqlite3Nif.column_names(connection, prepared_statement, ref, self())
    receive_answer(ref, timeout)
  end

  @doc "Return the column types of the prepared statement."
  @spec column_types(prepared_statement) :: tuple | error_tup2
  def column_types(prepared_statement), do: column_types(prepared_statement, @default_timeout)

  @doc "Return the column types of the prepared statement."
  @spec column_types(prepared_statement, timeout) :: tuple | error_tup2
  def column_types(prepared_statement, timeout)

  def column_types({:statement, prepared_statement, {:connection, _ref, connection}}, timeout) do
    ref = make_ref()
    :ok = Esqlite3Nif.column_types(connection, prepared_statement, ref, self())
    receive_answer(ref, timeout)
  end

  @doc "Close the database connection."
  @spec close(connection) :: :ok | error_tup2
  def close(connection), do: close(connection, @default_timeout)

  @doc "Close the database connection."
  @spec close(connection, timeout) :: :ok | error_tup2
  def close(connection, timeout)

  def close({:connection, _ref, connection}, timeout) do
    ref = make_ref()
    :ok = Esqlite3Nif.close(connection, ref, self())
    receive_answer(ref, timeout)
  end

  @doc "Enable the database to load extensions"
  @spec enable_load_extension(connection) :: :ok | error_tup2
  def enable_load_extension(connection), do: enable_load_extension(connection, @default_timeout)

  @doc "Enable the database to load extensions"
  @spec enable_load_extension(connection, timeout) :: :ok | error_tup2
  def enable_load_extension(connection, timeout)
  def enable_load_extension({:connection, _ref, connection}, timeout) do
    ref = make_ref()
    :ok = Esqlite3Nif.enable_load_extension(connection, ref, self())
    receive_answer(ref, timeout)
  end

  @doc "Execute a sql statement, returns a list with tuples."
  def q(sql, connection), do: q(sql, [], connection)

  @doc "Execute a sql statement, returns a list with tuples."
  def q(sql, [], connection) do
    case prepare(sql, connection) do
      {:ok, statement} -> fetchall(statement)
      {:error, _} = err -> throw(err)
    end
  end

  def q(sql, args, connection) do
    case prepare(sql, connection) do
      {:ok, statement} ->
        :ok = bind(statement, args)
        fetchall(statement)

      {:error, _} = err ->
        throw(err)
    end
  end

  @doc """
  Enumerate `sql` applying `f` to each result.
  """
  def map(f, sql, connection) do
    case prepare(sql, connection) do
      {:ok, statement} -> map_s(f, statement)
      {:error, _} = err -> throw(err)
    end
  end

  defp map_s(f, statement) when is_function(f, 1) do
    case try_step(statement, 0) do
      :"$done" -> []
      {:error, _} = e -> f.(e)
      {:row, row} -> [f.(row) | map_s(f, statement)]
    end
  end

  defp map_s(f, statement) when is_function(f, 2) do
    column_names = column_names(statement)

    case try_step(statement, 0) do
      :"$done" -> []
      {:error, _} = e -> f.([], e)
      {:row, row} -> [f.(column_names, row) | map_s(f, statement)]
    end
  end

  @doc "Apply a function over the results of SQL query."
  def foreach(f, sql, connection) do
    case prepare(sql, connection) do
      {:ok, statement} -> foreach_s(f, statement)
      {:error, _} = err -> throw(err)
    end
  end

  defp foreach_s(f, statement) when is_function(f, 1) do
    case try_step(statement, 0) do
      :"$done" ->
        :ok

      {:error, _} = e ->
        f.(e)

      {:row, row} ->
        f.(row)
        foreach_s(f, statement)
    end
  end

  defp foreach_s(f, statement) when is_function(f, 2) do
    column_names = column_names(statement)

    case try_step(statement, 0) do
      :"$done" ->
        :ok

      {:error, _} = e ->
        f.([], e)

      {:row, row} ->
        f.(column_names, row)
        foreach_s(f, statement)
    end
  end

  @doc "Return the results of stepping into a `statement`."
  def fetchone(statement) do
    case try_step(statement, 0) do
      :"$done" -> :ok
      {:error, _} = e -> e
      {:row, row} -> row
    end
  end

  @doc "Return the results after enumerating an entire `statement`."
  def fetchall(statement) do
    case try_step(statement, 0) do
      :"$done" ->
        []

      {:error, _} = e ->
        e

      {:row, row} ->
        case fetchall(statement) do
          {:error, _} = e -> e
          rest -> [row | rest]
        end
    end
  end

  defp try_step(statement, tries)

  defp try_step(_statement, tries) when tries > 5, do: throw(:too_many_tries)

  defp try_step(statement, tries) do
    case step(statement) do
      :"$busy" ->
        :timer.sleep(100 * tries)
        try_step(statement, tries + 1)

      other ->
        other
    end
  end

  defp receive_answer(ref, timeout)
       when is_reference(ref) and (is_integer(timeout) or timeout == :infinity) do
    start = :os.timestamp()

    receive do
      {:esqlite3, ^ref, resp} ->
        resp

      {:esqlite3, _ref, _resp} = stale ->
        :ok = Logger.warn("Ignoring stale answer: #{inspect(stale)}")
        passed_mics = :os.timestamp() |> :timer.now_diff(start) |> div(1000)

        new_timeout =
          case timeout - passed_mics do
            passed when passed < 0 -> 0
            to -> to
          end

        receive_answer(ref, new_timeout)
    after
      timeout -> throw({:error, :timeout, ref})
    end
  end

  # This is to remove the default arg injection from the stacktrace.
  @compile {:inline, open: 1}
  @compile {:inline, exec: 2}
  @compile {:inline, changes: 1}
  @compile {:inline, insert: 2}
  @compile {:inline, prepare: 2}
  @compile {:inline, step: 1}
  @compile {:inline, reset: 1}
  @compile {:inline, bind: 2}
  @compile {:inline, column_names: 1}
  @compile {:inline, column_types: 1}
  @compile {:inline, close: 1}
end
