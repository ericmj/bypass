defmodule Bypass.Plug do
  def init([pid]), do: pid

  def call(conn, pid) do
    case Bypass.Instance.call(pid, :get_expects) do
      fun when is_function(fun, 1) ->
        run(conn, pid, fun)

      list when is_list(list) ->
        new_conn =
          Enum.find_value(list, fn {method, path, fun} ->
            if method == conn.method and path == conn.request_path do
              run(conn, pid, fun)
            end
          end)

        if new_conn do
          new_conn
        else
          put_result(pid, {:error, :unexpected_request})
          Plug.Conn.send_resp(conn, 500, "")
        end

      [] ->
        put_result(pid, {:error, :unexpected_request})
        Plug.Conn.send_resp(conn, 500, "")
    end
  end

  defp run(conn, pid, fun) do
    retain_current_plug(pid)
    try do
      fun.(conn)
    else
      conn ->
        put_result(pid, :ok_call)
        conn
    catch
      class, reason ->
        stacktrace = System.stacktrace
        put_result(pid, {:exit, {class, reason, stacktrace}})
        :erlang.raise(class, reason, stacktrace)
    end
  end

  defp retain_current_plug(pid), do: Bypass.Instance.cast(pid, {:retain_plug_process, self()})
  defp put_result(pid, result), do: Bypass.Instance.call(pid, {:put_expect_result, result})
end
