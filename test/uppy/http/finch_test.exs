defmodule Uppy.HTTP.FinchTest do
  use ExUnit.Case, async: true

  describe "head/3: " do
    test "returns expected response" do
      assert {:ok, response} = Uppy.HTTP.Finch.head("http://localhost/response-headers?content_type=image/png")

      assert %Uppy.HTTP.Finch.Response{
        status: 200,
        body: response_body,
        headers: _response_headers,
        request: %Finch.Request{
          scheme: :http,
          host: "localhost",
          port: 80,
          method: "HEAD",
          path: "/response-headers",
          headers: [],
          body: _response_request_body,
          query: "content_type=image/png",
          unix_socket: nil,
          private: %{}
        }
      } = response

      assert "" = response_body
    end
  end

  describe "get/3: " do
    test "returns expected response" do
      assert {:ok, response} = Uppy.HTTP.Finch.get("http://localhost/get")

      assert %Uppy.HTTP.Finch.Response{
        status: 200,
        body: response_body,
        headers: _response_headers,
        request: %Finch.Request{
          scheme: :http,
          host: "localhost",
          port: 80,
          method: "GET",
          path: "/get",
          headers: [],
          body: _response_request_body,
          query: nil,
          unix_socket: nil,
          private: %{}
        }
      } = response

      assert "" = response_body
    end
  end

  describe "delete/3: " do
    test "returns expected response" do
      assert {:ok, response} = Uppy.HTTP.Finch.delete("http://localhost/delete")

      assert %Uppy.HTTP.Finch.Response{
        status: 200,
        body: response_body,
        headers: _response_headers,
        request: %Finch.Request{
          scheme: :http,
          host: "localhost",
          port: 80,
          method: "DELETE",
          path: "/delete",
          headers: [],
          body: _response_request_body,
          query: nil,
          unix_socket: nil,
          private: %{}
        }
      } = response

      assert "" = response_body
    end
  end

  describe "post/3: " do
    test "returns expected response" do
      assert {:ok, response} = Uppy.HTTP.Finch.post("http://localhost/post", [], %{likes: 10})

      assert %Uppy.HTTP.Finch.Response{
        status: 200,
        body: response_body,
        headers: _response_headers,
        request: %Finch.Request{
          scheme: :http,
          host: "localhost",
          port: 80,
          method: "POST",
          path: "/post",
          headers: [],
          body: _response_request_body,
          query: nil,
          unix_socket: nil,
          private: %{}
        }
      } = response

      assert "" = response_body
    end
  end

  describe "patch/3: " do
    test "returns expected response" do
      assert {:ok, response} = Uppy.HTTP.Finch.patch("http://localhost/patch", [], %{likes: 10})

      assert %Uppy.HTTP.Finch.Response{
        status: 200,
        body: response_body,
        headers: _response_headers,
        request: %Finch.Request{
          scheme: :http,
          host: "localhost",
          port: 80,
          method: "PATCH",
          path: "/patch",
          headers: [],
          body: _response_request_body,
          query: nil,
          unix_socket: nil,
          private: %{}
        }
      } = response

      assert "" = response_body
    end
  end

  describe "put/3: " do
    test "returns expected response" do
      assert {:ok, response} = Uppy.HTTP.Finch.put("http://localhost/put", [], %{likes: 10})

      assert %Uppy.HTTP.Finch.Response{
        status: 200,
        body: response_body,
        headers: _response_headers,
        request: %Finch.Request{
          scheme: :http,
          host: "localhost",
          port: 80,
          method: "PUT",
          path: "/put",
          headers: [],
          body: _response_request_body,
          query: nil,
          unix_socket: nil,
          private: %{}
        }
      } = response

      assert "" = response_body
    end
  end
end
