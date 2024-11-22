defmodule Uppy.Phases.UpdateSchemaMetadataTest do
  use Uppy.DataCase, async: true
  doctest Uppy.Phases.UpdateSchemaMetadata

  alias Uppy.{
    Fixture,
    Phases.UpdateSchemaMetadata,
    Resolution,
    Schemas.FileInfoAbstract
  }

  describe "run/2" do
    test "copies schema data key object to destination object" do
      schema_data =
        Fixture.UserAvatarFileInfo.insert!(%{
          key: "temp/<USER_ID>-user/unique_identifier-image.jpeg",
          state: :available
        })

      schema_data_id = schema_data.id

      assert {:ok,
              %Resolution{
                state: :resolved,
                value: %Uppy.Schemas.FileInfoAbstract{
                  content_length: 11,
                  content_type: "text/plain",
                  e_tag: "e_tag",
                  id: ^schema_data_id,
                  key: ">DI_GRO<-organization/user-avatars/unique_identifier-image.jpeg",
                  last_modified: ~U[2024-07-24 01:00:00Z],
                  upload_id: nil
                },
                context: %{
                  destination_object:
                    ">DI_GRO<-organization/user-avatars/unique_identifier-image.jpeg"
                }
              }} =
               UpdateSchemaMetadata.run(
                 %Resolution{
                   bucket: "uppy-test",
                   query: {"user_avatar_file_infos", FileInfoAbstract},
                   state: :unresolved,
                   value: schema_data,
                   context: %{
                     destination_object:
                       ">DI_GRO<-organization/user-avatars/unique_identifier-image.jpeg",
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
