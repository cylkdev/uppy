# defmodule Uppy.ObjectPaths.TemporaryObjectPathTest do
#   use ExUnit.Case, async: true
#   doctest Uppy.ObjectPaths.TemporaryObjectPath

#   alias Uppy.ObjectPaths.TemporaryObjectPath

#   describe "&build_object_path/2" do
#     test "when basename is binary, returns expected response" do
#       assert "temp/21-user/image.jpeg" =
#         TemporaryObjectPath.build_object_path(
#           "12",
#           "user",
#           "image.jpeg",
#           []
#         )
#     end
#   end

#   describe "&build_object_path/5" do
#     test "returns expected response" do
#       assert "temp/21-user/image.jpeg" =
#         TemporaryObjectPath.build_object_path("12", "user", "image.jpeg", [])
#     end
#   end

#   describe "&validate_object_path/2" do
#     test "when path is a valid temporary path, return map" do
#       assert {:ok, %{
#         prefix: "temp",
#         id: "12",
#         partition_name: "user",
#         basename: "image.jpeg"
#       }} = TemporaryObjectPath.validate_object_path("temp/21-user/image.jpeg", [])
#     end

#     test "when path has invalid number of segments, return error" do
#       assert {
#         :error,
#         "temporary object path should have 3 segments",
#         %{
#           path: "temp/21-user/extra_section/image.jpeg",
#           segments: ["temp", "21-user", "extra_section", "image.jpeg"]
#         }
#       } = TemporaryObjectPath.validate_object_path("temp/21-user/extra_section/image.jpeg", [])
#     end

#     test "when prefix is invalid, return error" do
#       assert {
#         :error,
#         "temporary object path prefix is invalid",
#         %{
#           path: "invalid_prefix/21-user/image.jpeg"
#         }
#       } = TemporaryObjectPath.validate_object_path("invalid_prefix/21-user/image.jpeg", [])
#     end

#     test "when partition has invalid number of segments, return error" do
#       assert {
#         :error,
#         "temporary object path partition should have 2 segments",
#         %{
#           path: "temp/21-invalid-partition/image.jpeg",
#           segments: ["21", "invalid", "partition"]
#         }
#       } = TemporaryObjectPath.validate_object_path("temp/21-invalid-partition/image.jpeg", [])
#     end
#   end
# end
