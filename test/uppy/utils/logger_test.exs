defmodule Uppy.Utils.LoggerTest do
  use ExUnit.Case
  doctest Uppy.Utils.Logger

  import ExUnit.CaptureLog

  @logger_prefix "Uppy.Utils.LoggerTest"

  test "debug" do
    assert capture_log([level: :debug], fn ->
      Uppy.Utils.Logger.debug(@logger_prefix, "debug")
    end) =~ "[Uppy.Utils.LoggerTest] debug"
  end

  test "info" do
    assert capture_log([level: :info], fn ->
      Uppy.Utils.Logger.info(@logger_prefix, "info")
    end) =~ "[Uppy.Utils.LoggerTest] info"
  end

  test "warning" do
    assert capture_log([level: :warning], fn ->
      Uppy.Utils.Logger.warning(@logger_prefix, "warning")
    end) =~ "[Uppy.Utils.LoggerTest] warning"
  end

  test "error" do
    assert capture_log([level: :error], fn ->
      Uppy.Utils.Logger.error(@logger_prefix, "error")
    end) =~ "[Uppy.Utils.LoggerTest] error"
  end
end
