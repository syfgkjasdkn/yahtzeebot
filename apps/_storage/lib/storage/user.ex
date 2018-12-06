defmodule Storage.User do
  use TypedStruct

  typedstruct do
    field(:telegram_id, pos_integer, enforce: true)
    field(:rolls_left, non_neg_integer, enforce: true)
    field(:seedit_address, <<_::168>> | nil)
    field(:credit, non_neg_integer, enforce: true)
  end
end
