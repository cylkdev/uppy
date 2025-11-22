defmodule Uppy.Store do
  def delete_object(bucket, key, opts) do
    adapter(opts).delete_object(bucket, key, opts)
  end

  def copy_object(dest_bucket, dest_key, src_bucket, src_key, opts) do
    adapter(opts).copy_object(dest_bucket, dest_key, src_bucket, src_key, opts)
  end

  def head_object(bucket, key, opts) do
    adapter(opts).head_object(bucket, key, opts)
  end

  def pre_sign_post(bucket, key, opts) do
    adapter(opts).pre_sign_post(bucket, key, opts)
  end

  def pre_sign_part(bucket, key, upload_id, part_number, opts) do
    adapter(opts).pre_sign_part(bucket, key, upload_id, part_number, opts)
  end

  def list_parts(bucket, key, upload_id, opts) do
    adapter(opts).list_parts(bucket, key, upload_id, opts)
  end

  def complete_multipart_upload(bucket, key, upload_id, parts, opts) do
    adapter(opts).complete_multipart_upload(bucket, key, upload_id, parts, opts)
  end

  def abort_multipart_upload(bucket, key, upload_id, opts) do
    adapter(opts).abort_multipart_upload(bucket, key, upload_id, opts)
  end

  def create_multipart_upload(bucket, key, opts) do
    adapter(opts).create_multipart_upload(bucket, key, opts)
  end

  defp adapter(opts) do
    opts[:bucket][:adapter] || CloudCache.Adapters.S3
  end
end
