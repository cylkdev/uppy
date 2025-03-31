defmodule Uppy.Schedulers.ObanScheduler.RouterTest do
  use ExUnit.Case, async: true

  alias Uppy.Schedulers.ObanScheduler.Router

  describe "lookup_instance/1" do
    test "returns expected module for queue" do
      assert Uppy.Schedulers.Oban = Router.lookup_instance(:abort_expired_multipart_upload)
      assert Uppy.Schedulers.Oban = Router.lookup_instance(:abort_expired_upload)
      assert Uppy.Schedulers.Oban = Router.lookup_instance(:move_to_destination)
    end

    test "raises when module not configured for queue and default not set" do
      assert_raise(RuntimeError, fn ->
        Router.lookup_instance(:does_not_exist)
      end)
    end
  end

  describe "lookup_worker/1" do
    test "returns expected module for queue" do
      assert Uppy.Schedulers.ObanScheduler.Workers.AbortExpiredMultipartUploadWorker = Router.lookup_worker(:abort_expired_multipart_upload)
      assert Uppy.Schedulers.ObanScheduler.Workers.AbortExpiredUploadWorker = Router.lookup_worker(:abort_expired_upload)
      assert Uppy.Schedulers.ObanScheduler.Workers.MoveToDestinationWorker = Router.lookup_worker(:move_to_destination)
    end

    test "raises when module not configured for queue and default not set" do
      assert_raise(RuntimeError, fn ->
        Router.lookup_worker(:does_not_exist)
      end)
    end
  end
end
