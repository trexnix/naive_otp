defmodule NaiveOtp.GenServer do
  @moduledoc """
  A naive implementation of GenServer using plain Elixir/Erlang processes.
  """

  defmacro __using__(_) do
    quote do
      require Logger

      def handle_info(message, state) do
        Logger.error(
          "#{__MODULE__} received unexpected message in handle_info/2: #{inspect(message)}"
        )

        {:noreply, state}
      end

      defoverridable handle_info: 2
    end
  end

  @doc """
  Mimic some behaviours described here: https://hexdocs.pm/elixir/GenServer.html#start_link/3
  """
  def start_link(mod, init_arg, opts \\ []) do
    parent = self()

    spawn_link(fn ->
      # init/1 callback has to be called in the context of the new process
      case mod.init(init_arg) do
        {:ok, init_state} ->
          send(parent, {:"$initialized", {:ok, self()}})
          loop(mod, init_state)

        error ->
          send(parent, {:"$initialized", error})
      end
    end)

    # Do not return until the new child process confirmed it has finished initialization (aka init/1 has returned)
    receive do
      {:"$initialized", {:ok, pid}} -> {:ok, pid}
      {:"$initialized", {:stop, reason}} -> {:stop, reason}
      {:"$initialized", :ignore} -> :ignore
    end
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

      other_message ->
        {:noreply, new_state} = apply(mod, :handle_info, [other_message, state])
        loop(mod, new_state)
    end
  end
end
