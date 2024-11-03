defmodule Uppy.Phases.UpdateCompleteObjectMetadataTest do
  use Uppy.DataCase, async: true
  doctest Uppy.Phases.UpdateCompleteObjectMetadata

  alias Uppy.{
    Fixture,
    Resolution,
    Schemas.FileInfoAbstract,
    Phases.UpdateCompleteObjectMetadata
  }

  describe "run/2" do
    test "copies schema data key object to destination object" do
      schema_struct =
        Fixture.UserAvatarFileInfo.insert!(%{
          key: "temp/<USER_ID>-user/unique_identifier-image.jpeg",
          status: :available
        })

      schema_struct_id = schema_struct.id

      assert {:ok, %Resolution{
        state: :resolved,
        value: %Uppy.Schemas.FileInfoAbstract{
          content_length: 11,
          content_type: "text/plain",
          e_tag: "e_tag",
          filename: nil,
          id: ^schema_struct_id,
          key: ">DI_GRO<-organization/user-avatars/unique_identifier-image.jpeg",
          last_modified: ~U[2024-07-24 01:00:00Z],
          unique_identifier: nil,
          upload_id: nil,
          assoc_id: nil,
          user_id: nil
        },
        context: %{
          destination_object: ">DI_GRO<-organization/user-avatars/unique_identifier-image.jpeg"
        }
      }} =
        UpdateCompleteObjectMetadata.run(
          %Resolution{
            bucket: "uppy-test",
            query: {"user_avatar_file_infos", FileInfoAbstract},
            state: :unresolved,
            value: schema_struct,
            context: %{
              destination_object: ">DI_GRO<-organization/user-avatars/unique_identifier-image.jpeg",
              metadata: %{
                content_length: 11,
                content_type: "text/plain",
                e_tag: "e_tag",
                last_modified: ~U[2024-07-24 01:00:00Z]
              }
            }
          },
          []
        )
    end
  end
end
