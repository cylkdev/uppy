defmodule Uppy.Schedulers.ObanScheduler.EventName do
  @moduledoc "EventName names for oban workers"

  @event_abort_multipart_upload "uppy.abort_multipart_upload"
  @event_abort_upload "uppy.abort_upload"
  @event_move_upload "uppy.move_upload"

  @events [
    @event_abort_multipart_upload,
    @event_abort_upload,
    @event_move_upload
  ]

  @doc """
  Returns a list of event names

  ### Examples

      iex> Uppy.Schedulers.ObanScheduler.EventName.list()
      ["uppy.abort_multipart_upload", "uppy.abort_upload", "uppy.move_upload"]
  """
  @spec list :: list(binary())
  def list, do: @events

  @doc """
  Returns a string

  ### Examples

      iex> Uppy.Schedulers.ObanScheduler.EventName.abort_multipart_upload()
      "uppy.abort_multipart_upload"
  """
  @spec abort_multipart_upload :: binary()
  def abort_multipart_upload, do: @event_abort_multipart_upload

  @doc """
  Returns a string

  ### Examples

      iex> Uppy.Schedulers.ObanScheduler.EventName.abort_upload()
      "uppy.abort_upload"
  """
  @spec abort_upload :: binary()
  def abort_upload, do: @event_abort_upload

  @doc """
  Returns a string

  ### Examples

      iex> Uppy.Schedulers.ObanScheduler.EventName.move_upload()
      "uppy.move_upload"
  """
  @spec move_upload :: binary()
  def move_upload, do: @event_move_upload
end
