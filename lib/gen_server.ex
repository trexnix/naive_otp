defmodule NaiveOtp.GenServer do
  @moduledoc """
  A naive implementation of GenServer using plain Elixir/Erlang processes.
  """

  defmacro __using__(_) do
    quote do
    end
  end

  def start_link(mod, init_arg, opts \\ []) do
    pid =
      spawn_link(fn ->
        {:ok, init_state} = mod.init(init_arg)

        loop(mod, init_state)
      end)

    {:ok, pid}
  end

  def call(server_pid, request, timeout \\ 5000) do
    send(server_pid, {:"$call", self(), request})

    receive do
      {:"$call_resp", resp} -> resp
    after
      timeout ->
        raise "Timeout"
    end
  end

  def cast(server_pid, request) do
    send(server_pid, {:"$cast", request})
  end

  defp loop(mod, state) do
    receive do
      {:"$call", caller, request} ->
        {:reply, return_value, new_state} = apply(mod, :handle_call, [request, caller, state])
        send(caller, {:"$call_resp", return_value})
        loop(mod, new_state)

      {:"$cast", request} ->
        {:noreply, new_state} = apply(mod, :handle_cast, [request, state])
        loop(mod, new_state)
    end
  end
end
