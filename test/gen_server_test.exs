defmodule Counter do
  use NaiveOtp.GenServer

  def init(_state) do
    {:ok, 0}
  end

  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:increase, _from, state) do
    Process.sleep(1000)
    {:reply, state + 1, state + 1}
  end
end

defmodule GenServerTest do
  use ExUnit.Case

  describe "handle_call/3" do
    test "should return result" do
      {:ok, pid} = NaiveOtp.GenServer.start_link(Counter, nil)
      assert NaiveOtp.GenServer.call(pid, :get) == 0
      assert NaiveOtp.GenServer.call(pid, :increase) == 1
      assert NaiveOtp.GenServer.call(pid, :get) == 1
    end

    test "should raise error when timeout reached" do
      {:ok, pid} = NaiveOtp.GenServer.start_link(Counter, nil)
      assert NaiveOtp.GenServer.call(pid, :get) == 0

      assert_raise(RuntimeError, fn ->
        NaiveOtp.GenServer.call(pid, :increase, 100)
      end)
    end
  end
end
