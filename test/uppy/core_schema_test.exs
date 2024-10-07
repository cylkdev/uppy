defmodule Uppy.CoreSchemaTest do
  use Uppy.Support.DataCase, async: true

  alias Uppy.{
    Core,
    DBAction,
    Schedulers.Oban.ObanUtil
  }

  alias Uppy.Support.{
    Factory,
    Schemas,
    StorageSandbox,
    Testing,
    TestPipeline,
    Phases
  }

  @bucket "uppy-test"

  setup do
    organization = FactoryEx.insert!(Factory.Accounts.Organization)
    user = FactoryEx.insert!(Factory.Accounts.User, %{organization_id: organization.id})
    user_profile = FactoryEx.insert!(Factory.Accounts.UserProfile, %{user_id: user.id})
    user_avatar = FactoryEx.insert!(Factory.Accounts.UserAvatar, %{user_profile_id: user_profile.id})

    %{
      organization: organization,
      user: user,
      user_profile: user_profile,
      user_avatar: user_avatar
    }
  end

  setup do
    StorageSandbox.set_presigned_url_responses([
      {@bucket,
       fn _http_method, object ->
         {:ok,
          %{
            url: "https://url.com/#{object}",
            expires_at: ~U[2024-07-24 01:00:00Z]
          }}
       end}
    ])
  end

  describe "process_upload: " do
    test "processes object and updates record", context do
      organization_id = context.user.organization_id
      user_id = context.user.id
      user_avatar_id = context.user_avatar.id

      unique_identifier = "unique_identifier"

      permanent_key = "#{Testing.reverse_id(organization_id)}-company/user-avatars/#{unique_identifier}-image.jpeg"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: unique_identifier,
          filename: "image.jpeg",
          e_tag: "e_tag",
          key: permanent_key,
          user_avatar_id: user_avatar_id,
          user_id: user_id
        })

      assert {:ok, resolution, done} =
        Core.process_upload(
          @bucket,
          TestPipeline,
          "user-avatars",
          Schemas.UserAvatarObject,
          schema_data
        )

      assert %Uppy.Resolution{
        bucket: "uppy-test",
        context: %{},
        private: %{},
        query: Uppy.Support.Schemas.UserAvatarObject,
        resource: "user-avatars",
        state: :resolved,
        value: processed_schema_data
      } = resolution

      schema_data_id = schema_data.id

      complete_upload_phase_params = Phases.CompleteUploadPhase.params()

      assert %{
        content_length: 5,
        content_type: "image/jpeg",
        last_modified: ~U[2024-07-24 01:00:00Z]
      } === complete_upload_phase_params

      assert %Uppy.Support.Schemas.UserAvatarObject{
        content_length: 5,
        content_type: "image/jpeg",
        last_modified: ~U[2024-07-24 01:00:00Z],
        archived: false,
        archived_at: nil,
        e_tag: "e_tag",
        filename: "image.jpeg",
        id: ^schema_data_id,
        key: ^permanent_key,
        unique_identifier: ^unique_identifier,
        upload_id: nil,
        user_avatar_id: ^user_avatar_id,
        user_id: ^user_id
      } = processed_schema_data

      assert [Uppy.Support.Phases.CompleteUploadPhase] = done
    end
  end

  describe "garbage_collect_object: " do
    test "returns error if object has existing record", context do
      user_id = context.user.id
      user_avatar_id = context.user_avatar.id

      key = "key"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: "unique_identifier",
          filename: "image.jpeg",
          e_tag: "e_tag",
          key: key,
          user_avatar_id: user_avatar_id,
          user_id: user_id
        })

      assert {:error, error_message} =
        Core.garbage_collect_object(
          @bucket,
          Schemas.UserAvatarObject,
          key
        )

      assert %ErrorMessage{
        code: :forbidden,
        message: "cannot garbage collect existing record",
        details: %{
          params: %{key: "key"},
          query: Uppy.Support.Schemas.UserAvatarObject,
          schema_data: ^schema_data
        }
      } = error_message
    end

    test "when given params deletes object in storage if record not found, returns metadata when object found in storage", context do
      user_id = context.user.id
      user_avatar_id = context.user_avatar.id

      key = "key"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: "unique_identifier",
          filename: "image.jpeg",
          e_tag: "e_tag",
          key: key,
          user_avatar_id: user_avatar_id,
          user_id: user_id
        })

      schema_data_id = schema_data.id

      assert {:ok, %{id: ^schema_data_id}} = DBAction.delete(schema_data)

      sandbox_head_object_payload = %{
        content_length: 11,
        content_type: "text/plain",
        e_tag: "e_tag",
        last_modified: ~U[2024-07-24 01:00:00Z]
      }

      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:ok, sandbox_head_object_payload} end}
      ])

      sandbox_delete_object_payload =
        %{
          body: "",
          headers: [
            {"x-amz-id-2", "x_amz_id"},
            {"x-amz-request-id", "x_amz_request_id"},
            {"date", "Sat, 16 Sep 2023 04:13:38 GMT"},
            {"server", "AmazonS3"}
          ],
          status_code: 204
        }

      StorageSandbox.set_delete_object_responses([
        {@bucket, fn -> {:ok, sandbox_delete_object_payload} end}
      ])

      assert {:ok, garbage_collect_object_metadata}=
        Core.garbage_collect_object(
          @bucket,
          Schemas.UserAvatarObject,
          %{key: key}
        )

      assert garbage_collect_object_metadata === sandbox_head_object_payload
    end

    test "when given key deletes object in storage if record not found, returns metadata when object found in storage", context do
      user_id = context.user.id
      user_avatar_id = context.user_avatar.id

      key = "key"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: "unique_identifier",
          filename: "image.jpeg",
          e_tag: "e_tag",
          key: key,
          user_avatar_id: user_avatar_id,
          user_id: user_id
        })

      schema_data_id = schema_data.id

      assert {:ok, %{id: ^schema_data_id}} = DBAction.delete(schema_data)

      sandbox_head_object_payload = %{
        content_length: 11,
        content_type: "text/plain",
        e_tag: "e_tag",
        last_modified: ~U[2024-07-24 01:00:00Z]
      }

      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:ok, sandbox_head_object_payload} end}
      ])

      sandbox_delete_object_payload =
        %{
          body: "",
          headers: [
            {"x-amz-id-2", "x_amz_id"},
            {"x-amz-request-id", "x_amz_request_id"},
            {"date", "Sat, 16 Sep 2023 04:13:38 GMT"},
            {"server", "AmazonS3"}
          ],
          status_code: 204
        }

      StorageSandbox.set_delete_object_responses([
        {@bucket, fn -> {:ok, sandbox_delete_object_payload} end}
      ])

      assert {:ok, garbage_collect_object_metadata}=
        Core.garbage_collect_object(
          @bucket,
          Schemas.UserAvatarObject,
          key
        )

      assert garbage_collect_object_metadata === sandbox_head_object_payload
    end

    test "deletes object in storage if record not found, does not return metadata when object not found in storage", context do
      user_id = context.user.id
      user_avatar_id = context.user_avatar.id

      key = "key"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: "unique_identifier",
          filename: "image.jpeg",
          e_tag: "e_tag",
          key: key,
          user_avatar_id: user_avatar_id,
          user_id: user_id
        })

      schema_data_id = schema_data.id

      assert {:ok, %{id: ^schema_data_id}} = DBAction.delete(schema_data)

      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:error, %{code: :not_found}} end}
      ])

      assert {:ok, nil}=
        Core.garbage_collect_object(
          @bucket,
          Schemas.UserAvatarObject,
          key
        )
    end
  end

  describe "find_permanent_upload: " do
    test "returns record key in permanent path and e_tag not nil", context do
      organization_id = context.user.organization_id
      user_id = context.user.id
      user_avatar_id = context.user_avatar.id

      unique_identifier = "unique_identifier"

      permanent_key = "#{Testing.reverse_id(organization_id)}-company/user-avatars/#{unique_identifier}-image.jpeg"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: unique_identifier,
          filename: "image.jpeg",
          e_tag: "e_tag",
          key: permanent_key,
          user_avatar_id: user_avatar_id,
          user_id: user_id
        })

      schema_data_id = schema_data.id

      assert {:ok, %{id: ^schema_data_id}} =
        Core.find_permanent_upload(
          Schemas.UserAvatarObject,
          %{id: schema_data_id}
        )
    end

    test "returns error when record key in permanent path and e_tag is nil", context do
      organization_id = context.user.organization_id
      user_id = context.user.id
      user_avatar_id = context.user_avatar.id

      unique_identifier = "unique_identifier"

      permanent_key = "#{Testing.reverse_id(organization_id)}-company/user-avatars/#{unique_identifier}-image.jpeg"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: unique_identifier,
          filename: "image.jpeg",
          key: permanent_key,
          user_avatar_id: user_avatar_id,
          user_id: user_id
        })

      schema_data_id = schema_data.id

      assert {:error, error_message} =
        Core.find_permanent_upload(
          Schemas.UserAvatarObject,
          %{id: schema_data_id}
        )

      assert %ErrorMessage{
        code: :forbidden,
        details: %{
          schema_data: %{id: ^schema_data_id}
        },
        message: "Expected `:e_tag` to be non-nil"
      } = error_message
    end

    test "returns record key not in permanent path and e_tag not nil", context do
      user_id = context.user.id
      user_avatar_id = context.user_avatar.id

      unique_identifier = "unique_identifier"

      temp_key = "temp/#{Testing.reverse_id(user_id)}-user/#{unique_identifier}-image.jpeg"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: unique_identifier,
          filename: "image.jpeg",
          e_tag: "e_tag",
          key: temp_key,
          user_avatar_id: user_avatar_id,
          user_id: user_id
        })

      schema_data_id = schema_data.id

      assert {:error, error_message} =
        Core.find_permanent_upload(
          Schemas.UserAvatarObject,
          %{id: schema_data_id}
        )

      assert %ErrorMessage{
        code: :forbidden,
        details: %{path: ^temp_key},
        message: "not a permanent path"
      } = error_message
    end
  end

  describe "find_completed_upload: " do
    test "returns record key in temporary path and e_tag not nil", context do
      user_id = context.user.id
      user_avatar_id = context.user_avatar.id

      unique_identifier = "unique_identifier"

      temp_key = "temp/#{Testing.reverse_id(user_id)}-user/#{unique_identifier}-image.jpeg"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: unique_identifier,
          filename: "image.jpeg",
          e_tag: "e_tag",
          key: temp_key,
          user_avatar_id: user_avatar_id,
          user_id: user_id
        })

      schema_data_id = schema_data.id

      assert {:ok, %{id: ^schema_data_id}} =
        Core.find_completed_upload(
          Schemas.UserAvatarObject,
          %{id: schema_data_id}
        )
    end

    test "returns error when record key in temporary path and e_tag is nil", context do
      user_id = context.user.id
      user_avatar_id = context.user_avatar.id

      unique_identifier = "unique_identifier"

      temp_key = "temp/#{Testing.reverse_id(user_id)}-user/#{unique_identifier}-image.jpeg"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: unique_identifier,
          filename: "image.jpeg",
          key: temp_key,
          user_avatar_id: user_avatar_id,
          user_id: user_id
        })

      schema_data_id = schema_data.id

      assert {:error, error_message} =
        Core.find_completed_upload(
          Schemas.UserAvatarObject,
          %{id: schema_data_id}
        )

      assert %ErrorMessage{
        code: :forbidden,
        details: %{
          schema_data: %{id: ^schema_data_id}
        },
        message: "Expected `:e_tag` to be non-nil"
      } = error_message
    end

    test "returns record key not in temporary path and e_tag not nil", context do
      organization_id = context.user.organization_id
      user_id = context.user.id
      user_avatar_id = context.user_avatar.id

      unique_identifier = "unique_identifier"

      permanent_key = "#{Testing.reverse_id(organization_id)}-company/user-avatars/#{unique_identifier}-image.jpeg"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: unique_identifier,
          filename: "image.jpeg",
          e_tag: "e_tag",
          key: permanent_key,
          user_avatar_id: user_avatar_id,
          user_id: user_id
        })

      schema_data_id = schema_data.id

      assert {:error, error_message} =
        Core.find_completed_upload(
          Schemas.UserAvatarObject,
          %{id: schema_data_id}
        )

      assert %ErrorMessage{
        code: :forbidden,
        details: %{path: ^permanent_key},
        message: "not a temporary path"
      } = error_message
    end
  end

  describe "find_temporary_upload: " do
    test "returns record key in temporary path", context do
      user_id = context.user.id
      user_avatar_id = context.user_avatar.id

      unique_identifier = "unique_identifier"

      temp_key = "temp/#{Testing.reverse_id(user_id)}-user/#{unique_identifier}-image.jpeg"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: unique_identifier,
          filename: "image.jpeg",
          key: temp_key,
          user_avatar_id: user_avatar_id,
          user_id: user_id
        })

      schema_data_id = schema_data.id

      assert {:ok, %{id: ^schema_data_id}} =
        Core.find_temporary_upload(
          Schemas.UserAvatarObject,
          %{id: schema_data_id}
        )
    end

    test "returns error when record key not in temporary path", context do
      organization_id = context.user.organization_id
      user_id = context.user.id
      user_avatar_id = context.user_avatar.id

      unique_identifier = "unique_identifier"

      permanent_key = "#{Testing.reverse_id(organization_id)}-company/user-avatars/#{unique_identifier}-image.jpeg"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: unique_identifier,
          filename: "image.jpeg",
          key: permanent_key,
          user_avatar_id: user_avatar_id,
          user_id: user_id
        })

      schema_data_id = schema_data.id

      assert {:error, error_message} =
        Core.find_temporary_upload(
          Schemas.UserAvatarObject,
          %{id: schema_data_id}
        )

      assert %ErrorMessage{
        code: :forbidden,
        details: %{path: ^permanent_key},
        message: "not a temporary path"
      } = error_message
    end
  end

  describe "delete_upload: " do
    test "deleted record if key in permanent path and schedules garbage collection job", context do
      organization_id = context.user.organization_id
      user_id = context.user.id
      user_avatar_id = context.user_avatar.id

      unique_identifier = "unique_identifier"

      permanent_key = "#{Testing.reverse_id(organization_id)}-company/user-avatars/#{unique_identifier}-image.jpeg"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: unique_identifier,
          filename: "image.jpeg",
          e_tag: "e_tag",
          key: permanent_key,
          user_avatar_id: user_avatar_id,
          user_id: user_id
        })

      schema_data_id = schema_data.id

      assert {:ok, %{
        schema_data: delete_upload_schema_data,
        jobs: %{
          garbage_collect_object: garbage_collect_object_job
        }
      }} =
        Core.delete_upload(
          @bucket,
          Schemas.UserAvatarObject,
          %{id: schema_data_id}
        )

      assert %Uppy.Support.Schemas.UserAvatarObject{
        archived: false,
        archived_at: nil,
        content_length: nil,
        content_type: nil,
        e_tag: "e_tag",
        filename: "image.jpeg",
        id: ^schema_data_id,
        key: ^permanent_key,
        last_modified: nil,
        unique_identifier: ^unique_identifier,
        upload_id: nil,
        user_avatar_id: ^user_avatar_id,
        user_id: ^user_id
      } = delete_upload_schema_data

      assert %Oban.Job{
        args: %{
          event: "uppy.garbage_collect_object",
          bucket: "uppy-test",
          query: garbage_collect_object_job_query,
          key: ^permanent_key
        },
        attempt: 0,
        attempted_at: nil,
        attempted_by: nil,
        cancelled_at: nil,
        completed_at: nil,
        conf: nil,
        conflict?: false,
        discarded_at: nil,
        errors: [],
        id: _job_id,
        inserted_at: nil,
        max_attempts: 20,
        meta: %{},
        priority: nil,
        queue: "garbage_collection",
        replace: nil,
        scheduled_at: nil,
        state: "available",
        tags: [],
        unique: %{
          fields: [:args, :queue, :worker],
          keys: [],
          period: 300,
          states: [:available, :scheduled, :executing],
          timestamp: :inserted_at
        },
        unsaved_error: nil,
        worker: "Uppy.Schedulers.Oban.GarbageCollectionWorker"
      } = garbage_collect_object_job

      assert Uppy.Support.Schemas.UserAvatarObject = ObanUtil.decode_binary_to_term(garbage_collect_object_job_query)
    end

    test "deleted record if key in permanent path and does not schedule garbage collection job when scheduler disabled", context do
      organization_id = context.user.organization_id
      user_id = context.user.id
      user_avatar_id = context.user_avatar.id

      unique_identifier = "unique_identifier"

      permanent_key = "#{Testing.reverse_id(organization_id)}-company/user-avatars/#{unique_identifier}-image.jpeg"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: unique_identifier,
          filename: "image.jpeg",
          e_tag: "e_tag",
          key: permanent_key,
          user_avatar_id: user_avatar_id,
          user_id: user_id
        })

      schema_data_id = schema_data.id

      assert {:ok, %{
        schema_data: delete_upload_schema_data
      } = delete_upload_response} =
        Core.delete_upload(
          @bucket,
          Schemas.UserAvatarObject,
          %{id: schema_data_id},
          scheduler_enabled: false
        )

      assert %Uppy.Support.Schemas.UserAvatarObject{
        archived: false,
        archived_at: nil,
        content_length: nil,
        content_type: nil,
        e_tag: "e_tag",
        filename: "image.jpeg",
        id: ^schema_data_id,
        key: ^permanent_key,
        last_modified: nil,
        unique_identifier: ^unique_identifier,
        upload_id: nil,
        user_avatar_id: ^user_avatar_id,
        user_id: ^user_id
      } = delete_upload_schema_data

      assert %{
        schema_data: delete_upload_schema_data
      } === delete_upload_response
    end
  end

  describe "complete_upload: " do
    test "updates e_tag of record and creates post processing job", context do
      user_id = context.user.id
      user_avatar_id = context.user_avatar.id

      unique_identifier = "unique_identifier"

      temp_key = "temp/#{Testing.reverse_id(user_id)}-user/#{unique_identifier}-image.jpeg"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: unique_identifier,
          filename: "image.jpeg",
          key: temp_key,
          user_avatar_id: user_avatar_id,
          user_id: user_id
        })

      schema_data_id = schema_data.id

      sandbox_head_object_payload = %{
        content_length: 11,
        content_type: "text/plain",
        e_tag: "e_tag",
        last_modified: ~U[2024-07-24 01:00:00Z]
      }

      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:ok, sandbox_head_object_payload} end}
      ])

      assert {:ok, %{
        metadata: complete_upload_metadata,
        schema_data: complete_upload_schema_data,
        jobs: %{
          process_upload: process_upload_job
        }
      }} =
        Core.complete_upload(
          @bucket,
          "user-avatars",
          Uppy.Support.TestPipeline,
          Schemas.UserAvatarObject,
          %{id: schema_data_id}
        )

      assert sandbox_head_object_payload === complete_upload_metadata

      assert %Uppy.Support.Schemas.UserAvatarObject{
        archived: false,
        archived_at: nil,
        content_length: nil,
        content_type: nil,
        e_tag: "e_tag",
        filename: "image.jpeg",
        id: ^schema_data_id,
        key: ^temp_key,
        last_modified: nil,
        unique_identifier: ^unique_identifier,
        upload_id: nil,
        user_avatar_id: ^user_avatar_id,
        user_id: ^user_id
      } = complete_upload_schema_data

      assert %Oban.Job{
        args: %{
          event: "uppy.process_upload",
          bucket: "uppy-test",
          pipeline: "Uppy.Support.TestPipeline",
          resource: "user-avatars",
          query: process_upload_job_query,
          id: ^schema_data_id
        },
        attempt: 0,
        attempted_at: nil,
        attempted_by: nil,
        cancelled_at: nil,
        completed_at: nil,
        conf: nil,
        conflict?: false,
        discarded_at: nil,
        errors: [],
        id: _job_id,
        inserted_at: nil,
        max_attempts: 20,
        meta: %{},
        priority: nil,
        queue: "post_processing",
        replace: nil,
        scheduled_at: nil,
        state: "available",
        tags: [],
        unique: %{
          fields: [:args, :queue, :worker],
          keys: [],
          period: 300,
          states: [:available, :scheduled, :executing],
          timestamp: :inserted_at
        },
        unsaved_error: nil,
        worker: "Uppy.Schedulers.Oban.PostProcessingWorker"
      } = process_upload_job

      assert Uppy.Support.Schemas.UserAvatarObject = ObanUtil.decode_binary_to_term(process_upload_job_query)
    end

    test "updates e_tag of record and does not create post processing job when scheduler disabled", context do
      user_id = context.user.id
      user_avatar_id = context.user_avatar.id

      unique_identifier = "unique_identifier"

      temp_key = "temp/#{Testing.reverse_id(user_id)}-user/#{unique_identifier}-image.jpeg"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: unique_identifier,
          filename: "image.jpeg",
          key: temp_key,
          user_avatar_id: user_avatar_id,
          user_id: user_id
        })

      schema_data_id = schema_data.id

      sandbox_head_object_payload = %{
        content_length: 11,
        content_type: "text/plain",
        e_tag: "e_tag",
        last_modified: ~U[2024-07-24 01:00:00Z]
      }

      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:ok, sandbox_head_object_payload} end}
      ])

      assert {:ok, %{
        metadata: complete_upload_metadata,
        schema_data: complete_upload_schema_data
      } = complete_upload_response} =
        Core.complete_upload(
          @bucket,
          "user-avatars",
          Uppy.Support.TestPipeline,
          Schemas.UserAvatarObject,
          %{id: schema_data_id},
          %{},
          scheduler_enabled: false
        )

      assert sandbox_head_object_payload === complete_upload_metadata

      assert %Uppy.Support.Schemas.UserAvatarObject{
        archived: false,
        archived_at: nil,
        content_length: nil,
        content_type: nil,
        e_tag: "e_tag",
        filename: "image.jpeg",
        id: ^schema_data_id,
        key: ^temp_key,
        last_modified: nil,
        unique_identifier: "unique_identifier",
        upload_id: nil,
        user_avatar_id: ^user_avatar_id,
        user_id: ^user_id
      } = complete_upload_schema_data

      assert %{
        metadata: complete_upload_metadata,
        schema_data: complete_upload_schema_data
      } === complete_upload_response
    end
  end

  describe "abort_upload: " do
    test "deletes temporary record and schedules garbage collection", context do
      user_id = context.user.id
      user_avatar_id = context.user_avatar.id

      unique_identifier = "unique_identifier"

      temp_key = "temp/#{Testing.reverse_id(user_id)}-user/#{unique_identifier}-image.jpeg"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: unique_identifier,
          filename: "image.jpeg",
          key: temp_key,
          user_avatar_id: user_avatar_id,
          user_id: user_id
        })

      schema_data_id = schema_data.id

      assert {:ok, %{
        schema_data: abort_upload_schema_data,
        jobs: %{
          garbage_collect_object: garbage_collect_object_job
        }
      }} =
        Core.abort_upload(
          @bucket,
          Schemas.UserAvatarObject,
          %{id: schema_data_id}
        )

      assert schema_data.id === abort_upload_schema_data.id

      assert {:error, %{code: :not_found}} = DBAction.find(Schemas.UserAvatarObject, %{id: schema_data_id})

      assert %Oban.Job{
        args: %{
          event: "uppy.garbage_collect_object",
          bucket: "uppy-test",
          query: garbage_collect_object_job_query,
          key: ^temp_key
        },
        attempt: 0,
        attempted_at: nil,
        attempted_by: nil,
        cancelled_at: nil,
        completed_at: nil,
        conf: nil,
        conflict?: false,
        discarded_at: nil,
        errors: [],
        id: _job_id,
        inserted_at: nil,
        max_attempts: 20,
        meta: %{},
        priority: nil,
        queue: "garbage_collection",
        replace: nil,
        scheduled_at: nil,
        state: "available",
        tags: [],
        unique: %{
          fields: [:args, :queue, :worker],
          keys: [],
          period: 300,
          states: [:available, :scheduled, :executing],
          timestamp: :inserted_at
        },
        unsaved_error: nil,
        worker: "Uppy.Schedulers.Oban.GarbageCollectionWorker"
      } = garbage_collect_object_job

      assert Uppy.Support.Schemas.UserAvatarObject = ObanUtil.decode_binary_to_term(garbage_collect_object_job_query)
    end

    test "deletes temporary record and does not schedule garbage collection when scheduler disabled", context do
      user_id = context.user.id
      user_avatar_id = context.user_avatar.id

      assert {:ok, %{
        unique_identifier: unique_identifier,
        key: temp_key,
        schema_data: schema_data
      }} =
        Core.start_upload(
          @bucket,
          user_id,
          Schemas.UserAvatarObject,
          %{
            filename: "image.jpeg",
            user_id: user_id,
            user_avatar_id: user_avatar_id
          }
        )

      assert "temp/#{Testing.reverse_id(user_id)}-user/#{unique_identifier}-image.jpeg" === temp_key

      schema_data_id = schema_data.id

      assert {:ok, %{
        schema_data: abort_upload_schema_data
      } = abort_upload_response} =
        Core.abort_upload(
          @bucket,
          Schemas.UserAvatarObject,
          %{id: schema_data_id},
          scheduler_enabled: false
        )

      assert schema_data.id === abort_upload_schema_data.id

      assert {:error, %{code: :not_found}} = DBAction.find(Schemas.UserAvatarObject, %{id: schema_data_id})

      assert %{
        schema_data: abort_upload_schema_data
      } === abort_upload_response
    end
  end

  describe "start_upload: " do
    test "creates record, creates presigned upload, and creates job", context do
      user_id = context.user.id
      user_avatar_id = context.user_avatar.id

      assert {:ok, %{
        unique_identifier: unique_identifier,
        basename: basename,
        key: temp_key,
        presigned_upload: presigned_upload,
        schema_data: schema_data,
        jobs: %{
          abort_upload: abort_upload_job
        }
      }} =
        Core.start_upload(
          @bucket,
          user_id,
          Schemas.UserAvatarObject,
          %{
            filename: "image.jpeg",
            user_id: user_id,
            user_avatar_id: user_avatar_id
          }
        )

      assert is_binary(unique_identifier)
      assert is_binary(basename)

      assert "temp/#{Testing.reverse_id(user_id)}-user/#{unique_identifier}-image.jpeg" === temp_key

      assert %{
        url: presigned_upload_url,
        expires_at: expires_at
      } = presigned_upload

      assert is_binary(presigned_upload_url)
      assert %DateTime{} = expires_at

      assert %Uppy.Support.Schemas.UserAvatarObject{
        archived: false,
        archived_at: nil,
        content_length: nil,
        content_type: nil,
        e_tag: nil,
        filename: "image.jpeg",
        id: schema_data_id,
        key: ^temp_key,
        last_modified: nil,
        unique_identifier: ^unique_identifier,
        upload_id: nil,
        user_avatar_id: ^user_avatar_id,
        user_id: ^user_id
      } = schema_data

      assert %Oban.Job{
        args: %{
          event: "uppy.abort_upload",
          bucket: "uppy-test",
          query: abort_upload_job_query,
          id: ^schema_data_id
        },
        attempt: 0,
        attempted_at: nil,
        attempted_by: nil,
        cancelled_at: nil,
        completed_at: nil,
        conf: nil,
        conflict?: false,
        discarded_at: nil,
        errors: [],
        id: _job_id,
        inserted_at: nil,
        max_attempts: 20,
        meta: %{},
        priority: nil,
        queue: "abort_upload",
        replace: nil,
        scheduled_at: nil,
        state: "available",
        tags: [],
        unique: %{
          fields: [:args, :queue, :worker],
          keys: [],
          period: 300,
          states: [:available, :scheduled, :executing],
          timestamp: :inserted_at
        },
        unsaved_error: nil,
        worker: "Uppy.Schedulers.Oban.AbortUploadWorker"
      } = abort_upload_job

      assert Uppy.Support.Schemas.UserAvatarObject = ObanUtil.decode_binary_to_term(abort_upload_job_query)
    end

    test "creates record, creates presigned upload, and does not create job when scheduler disabled", context do
      user_id = context.user.id
      user_avatar_id = context.user_avatar.id

      assert {:ok, %{
        unique_identifier: unique_identifier,
        basename: basename,
        key: temp_key,
        presigned_upload: presigned_upload,
        schema_data: schema_data
      } = start_upload_response} =
        Core.start_upload(
          @bucket,
          user_id,
          Schemas.UserAvatarObject,
          %{
            filename: "image.jpeg",
            user_id: user_id,
            user_avatar_id: user_avatar_id
          },
          scheduler_enabled: false
        )

      assert is_binary(unique_identifier)
      assert is_binary(basename)

      assert "temp/#{Testing.reverse_id(user_id)}-user/#{unique_identifier}-image.jpeg" === temp_key

      assert %{
        url: presigned_upload_url,
        expires_at: expires_at
      } = presigned_upload

      assert is_binary(presigned_upload_url)
      assert %DateTime{} = expires_at

      assert %Uppy.Support.Schemas.UserAvatarObject{
        archived: false,
        archived_at: nil,
        content_length: nil,
        content_type: nil,
        e_tag: nil,
        filename: "image.jpeg",
        id: _schema_data_id,
        key: ^temp_key,
        last_modified: nil,
        unique_identifier: ^unique_identifier,
        upload_id: nil,
        user_avatar_id: ^user_avatar_id,
        user_id: ^user_id
      } = schema_data

      assert %{
        unique_identifier: unique_identifier,
        basename: basename,
        key: temp_key,
        presigned_upload: presigned_upload,
        schema_data: schema_data
      } === start_upload_response
    end
  end
end
