defmodule Uppy.Phases.PutPermanentObjectCopyTest do
  use Uppy.DataCase, async: true
  doctest Uppy.Phases.PutPermanentObjectCopy

  alias Uppy.{
    Fixture,
    Phases.PutPermanentObjectCopy,
    Resolution,
    StorageSandbox
  }

  describe "run/2" do
    test "copies schema data key object to destination object" do
      schema_data =
        Fixture.UserAvatarFileInfo.insert!(%{
          key: "temp/<USER_ID>-user/unique_identifier-image.jpeg",
          state: :available
        })

      StorageSandbox.set_put_object_copy_responses([
        {
          ~r|.*|,
          fn ->
            {:ok,
             %{
               body: "body",
               headers: [
                 {"x-amz-id-2", "amz_id"},
                 {"x-amz-request-id", "C6KG1R8WTNFSTX5F"},
                 {"date", "Sat, 16 Sep 2023 01:57:35 GMT"},
                 {"x-amz-server-side-encryption", "AES256"},
                 {"content-type", "application/xml"},
                 {"server", "AmazonS3"},
                 {"content-length", "224"}
               ],
               status_code: 200
             }}
          end
        }
      ])

      assert {:ok,
              %Resolution{
                state: :unresolved,
                value: ^schema_data,
                context: %{
                  destination_object:
                    ">DI_GRO<-organization/user-avatars/unique_identifier-image.jpeg"
                }
              }} =
               PutPermanentObjectCopy.run(
                 %Resolution{
                   bucket: "uppy-test",
                   state: :unresolved,
                   value: schema_data,
                   context: %{
                     destination_object:
                       ">DI_GRO<-organization/user-avatars/unique_identifier-image.jpeg"
                   }
                 },
                 []
               )
    end
  end
end
