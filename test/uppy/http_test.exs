defmodule Uppy.HTTPTest do
  use ExUnit.Case, async: true

  @moduletag :external

  describe "head/3: " do
    test "returns expected response" do
      assert {:ok, {body, response}} = Uppy.HTTP.head("http://localhost/response-headers?content_type=image/png")

      assert "" = body

      assert %Uppy.HTTP.Finch.Response{
        status: 200,
        body: _response_body,
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
    end
  end

  describe "get/3: " do
    test "returns expected response" do
      assert {:ok, {body, response}} = Uppy.HTTP.get("http://localhost/get")

      assert %{
        args: %{},
        origin: "192.168.65.1",
        url: "http://localhost/get",
        headers: %{
          Host: "localhost",
          "User-Agent": "mint/1.6.2"
        }
      } = body

      assert %Uppy.HTTP.Finch.Response{
        status: 200,
        body: _response_body,
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
    end
  end

  describe "delete/3: " do
    test "returns expected response" do
      assert {:ok, {body, response}} = Uppy.HTTP.delete("http://localhost/delete")

      assert %{
        args: %{},
        origin: "192.168.65.1",
        url: "http://localhost/delete",
        headers: %{
          Host: "localhost",
          "User-Agent": "mint/1.6.2"
        }
      } = body

      assert %Uppy.HTTP.Finch.Response{
        status: 200,
        body: _response_body,
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
    end
  end

  describe "post/3: " do
    test "returns expected response" do
      assert {:ok, {body, response}} = Uppy.HTTP.post("http://localhost/post", %{likes: 10})

      assert %{
        args: %{},
        origin: "192.168.65.1",
        url: "http://localhost/post",
        headers: %{
          Host: "localhost",
          "User-Agent": "mint/1.6.2"
        }
      } = body

      assert %Uppy.HTTP.Finch.Response{
        status: 200,
        body: _response_body,
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
    end
  end

  describe "patch/3: " do
    test "returns expected response" do
      assert {:ok, {body, response}} = Uppy.HTTP.patch("http://localhost/patch", %{likes: 10})

      assert %{
        args: %{},
        origin: "192.168.65.1",
        url: "http://localhost/patch",
        headers: %{
          Host: "localhost",
          "User-Agent": "mint/1.6.2"
        }
      } = body

      assert %Uppy.HTTP.Finch.Response{
        status: 200,
        body: _response_body,
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
    end
  end

  describe "put/3: " do
    test "returns expected response" do
      assert {:ok, {body, response}} = Uppy.HTTP.put("http://localhost/put", %{likes: 10})

      assert %{
        args: %{},
        origin: "192.168.65.1",
        url: "http://localhost/put",
        headers: %{
          Host: "localhost",
          "User-Agent": "mint/1.6.2"
        }
      } = body

      assert %Uppy.HTTP.Finch.Response{
        status: 200,
        body: _response_body,
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
    end
  end
end
