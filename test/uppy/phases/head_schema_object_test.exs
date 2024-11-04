defmodule Uppy.Phases.HeadSchemaObjectTest do
  use Uppy.DataCase, async: true
  doctest Uppy.Phases.HeadSchemaObject

  alias Uppy.{
    Fixture,
    Phases.HeadSchemaObject,
    Resolution,
    StorageSandbox
  }

  @bucket "uppy-test"

  describe "run/2" do
    test "adds metadata to context" do
      schema_struct =
        Fixture.UserAvatarFileInfo.insert!(%{
          key: "temp/<USER_ID>-user/unique_identifier-image.jpeg",
          state: :available
        })

      # object must exist
      StorageSandbox.set_head_object_responses([
        {
          @bucket,
          fn ->
            {:ok, %{
              content_length: 11,
              content_type: "text/plain",
              e_tag: "e_tag",
              last_modified: ~U[2024-07-24 01:00:00Z]
            }}
          end
        }
      ])

      assert {:ok, %Resolution{
        state: :unresolved,
        value: ^schema_struct,
        context: %{
          destination_object: ">DI_GRO<-organization/user-avatars/unique_identifier-image.jpeg",
          # metadata data from storage should exist
          metadata: %{
            content_length: 11,
            content_type: "text/plain",
            e_tag: "e_tag",
            last_modified: ~U[2024-07-24 01:00:00Z]
          }
        }
      }} =
        HeadSchemaObject.run(
          %Resolution{
            bucket: "uppy-test",
            state: :unresolved,
            value: schema_struct,
            context: %{
              destination_object: ">DI_GRO<-organization/user-avatars/unique_identifier-image.jpeg"
            }
          },
          []
        )
    end
  end
end
