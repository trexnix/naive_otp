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

  def handle_cast(:increase, state) do
    {:noreply, state + 1}
  end
end

defmodule GenServerTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  describe "start_link/3" do
    test "must block until init/3 of given module has returned" do
      defmodule GenServerTest.InitTest1 do
        use NaiveOtp.GenServer

        def init(_state) do
          Process.sleep(100)
          {:ok, nil}
        end
      end

      time_start = NaiveDateTime.utc_now()
      {:ok, pid} = NaiveOtp.GenServer.start_link(GenServerTest.InitTest1, nil)
      time_end = NaiveDateTime.utc_now()

      assert NaiveDateTime.diff(time_end, time_start, :millisecond) > 100
      assert Process.alive?(pid)
    end

    test "must return respective errors when init/3 failed" do
      defmodule GenServerTest.InitTest2 do
        use NaiveOtp.GenServer

        def init(_state) do
          {:stop, :not_ok_at_all}
        end
      end

      assert {:stop, :not_ok_at_all} = NaiveOtp.GenServer.start_link(GenServerTest.InitTest2, nil)

      defmodule GenServerTest.InitTest3 do
        use NaiveOtp.GenServer

        def init(_state) do
          :ignore
        end
      end

      assert :ignore = NaiveOtp.GenServer.start_link(GenServerTest.InitTest3, nil)
    end
  end

  describe ":sys module" do
    test "should responds current state to :sys.get_state/1 call" do
      defmodule GenServerTest.Sys0 do
        use NaiveOtp.GenServer

        def init(_state) do
          {:ok, 0}
        end
      end

      {:ok, pid} = NaiveOtp.GenServer.start_link(GenServerTest.Sys0, nil)

      assert :sys.get_state(pid) == 0
    end

    test "should set new state via :sys.replace_state/2 call" do
      defmodule GenServerTest.Sys1 do
        use NaiveOtp.GenServer

        def init(_state) do
          {:ok, 0}
        end
      end

      {:ok, pid} = NaiveOtp.GenServer.start_link(GenServerTest.Sys1, nil)

      :sys.replace_state(pid, fn _current_state -> 1 end)
      assert :sys.get_state(pid) == 1
    end
  end

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

  describe "handle_cast/2" do
    test "should return result" do
      {:ok, pid} = NaiveOtp.GenServer.start_link(Counter, nil)

      assert NaiveOtp.GenServer.call(pid, :get) == 0
      NaiveOtp.GenServer.cast(pid, :increase)
      assert :sys.get_state(pid) == 1
    end
  end

  describe "handle_info/2" do
    test "should use the default handle_info/2 callback" do
      defmodule GenServerTest.HandleInfo1 do
        use NaiveOtp.GenServer

        def init(_state) do
          {:ok, 0}
        end
      end

      {:ok, pid} = NaiveOtp.GenServer.start_link(GenServerTest.HandleInfo1, nil)

      assert capture_log(fn ->
               send(pid, :strange_message)
               Process.sleep(100)
             end) =~ "received unexpected message in handle_info/2"
    end

    test "should use user-defined handle_info/2 callback" do
      defmodule GenServerTest.HandleInfo2 do
        use NaiveOtp.GenServer

        def init(_state) do
          {:ok, 0}
        end

        def handle_info(:expected_message, state) do
          {:noreply, state + 1}
        end

        def handle_call(:get, _from, state) do
          {:reply, state, state}
        end
      end

      {:ok, pid} = NaiveOtp.GenServer.start_link(GenServerTest.HandleInfo2, nil)

      send(pid, :expected_message)

      assert :sys.get_state(pid) == 1
    end
  end
end
