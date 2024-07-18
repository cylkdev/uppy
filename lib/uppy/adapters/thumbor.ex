if Uppy.Utils.application_loaded?(:thumbor) do
  defmodule Uppy.Adapters.Thumbor do
    config = Uppy.Config.thumbor()

    @host config[:host] || "http://localhost:80"
    @security_code config[:security_code]
    @http_adapter config[:http_adapter] || Uppy.Adapters.HTTP.Finch
    @storage_adapter config[:storage_adapter] || Uppy.Adapters.Storage.S3

    def build_url(image_url, params) do
      Thumbor.build_url(image_url, params)
    end

    def build_request(url) do
      Thumbor.build_request(@host, @security_code, url)
    end

    def request(url, options) do
      Thumbor.request(
        @http_adapter,
        @host,
        @security_code,
        url,
        options
      )
    end

    def find_result(bucket, image_url, params, options) do
      Thumbor.find_result(
        bucket,
        @storage_adapter,
        image_url,
        params,
        options
      )
    end

    def create_result(bucket, image_url, params, options) do
      Thumbor.create_result(
        bucket,
        @storage_adapter,
        @http_adapter,
        @host,
        @security_code,
        image_url,
        params,
        options
      )
    end

    def put_result(bucket, image_url, params, destination_object, options) do
      Thumbor.put_result(
        bucket,
        @storage_adapter,
        @http_adapter,
        @host,
        @security_code,
        image_url,
        params,
        destination_object,
        options
      )
    end
  end
end
