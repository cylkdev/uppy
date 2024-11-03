# defmodule Uppy.ObjectPathTest do
#   use ExUnit.Case, async: true
#   doctest Uppy.ObjectPath

#   alias Uppy.{
#     ObjectPath,
#     PermanentObjectPath
#   }

#   describe "&build_object_path/2" do
#     test "returns expected response" do
#       assert "53-organization/user-avatars/image.jpeg"=
#         ObjectPath.build_object_path(
#           PermanentObjectPath,
#           %{
#             id: "35",
#             partition_name: "organization",
#             basename: "image.jpeg"
#           },
#           []
#         )
#     end
#   end

#   describe "&build_object_path/5" do
#     test "returns expected response" do
#       assert "53-organization/user-avatars/image.jpeg" =
#         ObjectPath.build_object_path(
#           PermanentObjectPath,
#           "35",
#           "organization",
#           "user-avatars",
#           "image.jpeg",
#           []
#         )
#     end
#   end

#   describe "&validate_object_path/2" do
#     test "when key is a valid temporary key without prefix, return map" do
#       assert {:ok, %{
#         prefix: nil,
#         id: "53",
#         partition_name: "organization",
#         resource_name: "user-avatars",
#         basename: "image.jpeg"
#       }} = ObjectPath.validate_object_path(PermanentObjectPath, "35-organization/user-avatars/image.jpeg", [])
#     end
#   end
# end
