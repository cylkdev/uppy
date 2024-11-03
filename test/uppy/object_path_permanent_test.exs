# defmodule Uppy.ObjectPaths.PermanentObjectPathTest do
#   use ExUnit.Case, async: true
#   doctest Uppy.ObjectPaths.PermanentObjectPath

#   alias Uppy.ObjectPaths.PermanentObjectPath

#   describe "&build_object_path/2" do
#     test "when basename is binary, returns expected response" do
#       assert "53-organization/user-avatars/image.jpeg"=
#         PermanentObjectPath.build_object_path(
#           "35",
#           "organization",
#           "user-avatars/image.jpeg",
#           []
#         )
#     end
#   end

#   describe "&build_object_path/5" do
#     test "returns expected response" do
#       assert "53-organization/user-avatars/image.jpeg" =
#         PermanentObjectPath.build_object_path("35", "organization", "user-avatars/image.jpeg", [])
#     end
#   end

#   describe "&validate_object_path/2" do
#     test "when path is a valid temporary path without prefix, return map" do
#       assert {:ok, %{
#         prefix: nil,
#         id: "53",
#         partition_name: "organization",
#         resource_name: "user-avatars",
#         basename: "image.jpeg"
#       }} = PermanentObjectPath.validate_object_path("35-organization/user-avatars/image.jpeg", [])
#     end

#     test "when path has invalid number of segments, return error" do
#       assert {
#         :error,
#         "permanent object path should have 3 segments",
#         %{
#           path: "35-organization/user-avatars/extra_section/image.jpeg",
#           segments: ["35-organization", "user-avatars", "extra_section", "image.jpeg"],
#           object_path: PermanentObjectPath
#         }
#       } = PermanentObjectPath.validate_object_path("35-organization/user-avatars/extra_section/image.jpeg", [])
#     end

#     test "when partition has invalid number of segments, return error" do
#       assert {
#         :error,
#         "permanent object partition should have 2 segments",
#         %{
#           path: "35-organization-extra_section/user-avatars/image.jpeg",
#           segments: ["35", "organization", "extra_section"],
#           object_path: PermanentObjectPath
#         }
#       } = PermanentObjectPath.validate_object_path("35-organization-extra_section/user-avatars/image.jpeg", [])
#     end
#   end
# end
