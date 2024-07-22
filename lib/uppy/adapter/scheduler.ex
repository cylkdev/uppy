defmodule Uppy.Adapter.Scheduler do
  @type t_res :: {:ok, term()} | {:error, term()}

  @callback queue(
              action :: term(),
              params :: map(),
              maybe_max_age_or_date_time :: non_neg_integer() | DateTime.t() | nil,
              options :: Keyword.t()
            ) :: t_res()
end
