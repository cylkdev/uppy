defmodule Uppy.HTTP.FinchTest do
  use ExUnit.Case, async: true

  # tested via kennethreitz/httpbin
  @moduletag :external

  describe "head/3: " do
    test "returns expected response" do
      assert {:ok, {_body, response}} =
        Uppy.HTTP.Finch.head("http://localhost/response-headers?content_type=image/png", [], [])

      assert %Uppy.HTTP.Finch.Response{
        status: 200,
        request: %Finch.Request{
          scheme: :http,
          method: "HEAD"
        }
      } = response
    end
  end

  describe "get/3: " do
    test "returns expected response" do
      assert {:ok, {_body, response}} = Uppy.HTTP.Finch.get("http://localhost/get", [], [])

      assert %Uppy.HTTP.Finch.Response{
        status: 200,
        request: %Finch.Request{
          scheme: :http,
          method: "GET"
        }
      } = response
    end
  end

  describe "delete/3: " do
    test "returns expected response" do
      assert {:ok, {_body, response}} = Uppy.HTTP.Finch.delete("http://localhost/delete", [], [])

      assert %Uppy.HTTP.Finch.Response{
        status: 200,
        request: %Finch.Request{
          scheme: :http,
          method: "DELETE"
        }
      } = response
    end
  end

  describe "post/4: " do
    test "returns expected response" do
      json = Jason.encode!(%{likes: 10})

      assert {:ok, {_body, response}} = Uppy.HTTP.Finch.post("http://localhost/post", json, [], [])

      assert %Uppy.HTTP.Finch.Response{
        status: 200,
        request: %Finch.Request{
          scheme: :http,
          method: "POST"
        }
      } = response
    end
  end

  describe "patch/4: " do
    test "returns expected response" do
      json = Jason.encode!(%{likes: 10})

      assert {:ok, {_body, response}} = Uppy.HTTP.Finch.patch("http://localhost/patch", json, [], [])

      assert %Uppy.HTTP.Finch.Response{
        status: 200,
        request: %Finch.Request{
          scheme: :http,
          method: "PATCH"
        }
      } = response
    end
  end

  describe "put/4: " do
    test "returns expected response" do
      json = Jason.encode!(%{likes: 10})

      assert {:ok, {_body, response}} = Uppy.HTTP.Finch.put("http://localhost/put", json, [], [])

      assert %Uppy.HTTP.Finch.Response{
        status: 200,
        request: %Finch.Request{
          scheme: :http,
          method: "PUT"
        }
      } = response
    end
  end
end
