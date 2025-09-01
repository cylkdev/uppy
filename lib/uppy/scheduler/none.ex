defmodule Uppy.Core.Scheduler.None do
  def enqueue_save_upload(_query, _id, _opts) do
    {:ok, :none}
  end

  # ---

  def enqueue_handle_expired_upload(_query, _id, _opts) do
    {:ok, :none}
  end

  def enqueue_handle_expired_multipart_upload(_query, _id, _opts) do
    {:ok, :none}
  end

  # ---

  def enqueue_handle_aborted_upload(_query, _id, _opts) do
    {:ok, :none}
  end

  def enqueue_handle_aborted_multipart_upload(_query, _id, _opts) do
    {:ok, :none}
  end
end
