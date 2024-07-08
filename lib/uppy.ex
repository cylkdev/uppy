defmodule Uppy do
  @moduledoc """
  Documentation for `Uppy`.
  """

  @type adapter :: module()
  @type schema :: module()

  @type params :: map()
  @type body :: term()
  @type max_age_in_seconds :: non_neg_integer()
  @type options :: Keyword.t()

  @type http_method ::
          :get
          | :head
          | :post
          | :put
          | :delete
          | :connect
          | :options
          | :trace
          | :patch

  @type bucket :: String.t()
  @type prefix :: String.t()
  @type object :: String.t()

  @type e_tag :: String.t()
  @type upload_id :: String.t()
  @type marker :: String.t()
  @type maybe_marker :: marker() | nil
  @type part_number :: non_neg_integer()
  @type part :: {part_number(), e_tag()}
  @type parts :: list(part())
end
