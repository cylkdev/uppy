defmodule Uppy.Schedulers.Oban.EventName do
  @moduledoc """
  ...
  """

  @type event_name :: binary()

  @abort_upload                 "uppy.abort_upload"
  @abort_multipart_upload       "uppy.abort_multipart_upload"
  @garbage_collect_object       "uppy.garbage_collect_object"
  @process_upload               "uppy.process_upload"

  @doc """
  Returns a string.

  ### Examples

      iex> Uppy.Schedulers.Oban.EventName.abort_upload()
      "uppy.abort_upload"
  """
  @spec abort_upload :: event_name()
  def abort_upload, do: @abort_upload

  @doc """
  Returns a string.

  ### Examples

      iex> Uppy.Schedulers.Oban.EventName.abort_multipart_upload()
      "uppy.abort_multipart_upload"
  """
  @spec abort_multipart_upload :: event_name()
  def abort_multipart_upload, do: @abort_multipart_upload

  @doc """
  Returns a string.

  ### Examples

      iex> Uppy.Schedulers.Oban.EventName.garbage_collect_object()
      "uppy.garbage_collect_object"
  """
  @spec garbage_collect_object :: event_name()
  def garbage_collect_object, do: @garbage_collect_object

  @doc """
  Returns a string.

  ### Examples

      iex> Uppy.Schedulers.Oban.EventName.process_upload()
      "uppy.process_upload"
  """
  @spec process_upload :: event_name()
  def process_upload, do: @process_upload
end
