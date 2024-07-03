defmodule Uppy.Scheduler do
  def enqueue(adapter, action, params, maybe_seconds_or_date_time, options) do
    adapter.enqueue(action, params, maybe_seconds_or_date_time, options)
  end
end
