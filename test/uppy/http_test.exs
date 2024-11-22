defmodule Uppy.HTTPTest do
  use ExUnit.Case, async: true

  @moduletag :external

  describe "head/3: " do
    test "returns expected response" do
      assert {:ok, {_body, response}} =
               Uppy.HTTP.head("http://localhost/response-headers?content_type=image/png", [], [])

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
      assert {:ok, {_body, response}} = Uppy.HTTP.get("http://localhost/get", [], [])

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
      assert {:ok, {_body, response}} = Uppy.HTTP.delete("http://localhost/delete", [], [])

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
      assert {:ok, {_body, response}} =
               Uppy.HTTP.post("http://localhost/post", %{likes: 10}, [], [])

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
      assert {:ok, {_body, response}} =
               Uppy.HTTP.patch("http://localhost/patch", %{likes: 10}, [], [])

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
      assert {:ok, {_body, response}} =
               Uppy.HTTP.put("http://localhost/put", %{likes: 10}, [], [])

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
