defmodule Nc.Sync do
  # similar to the `xform` function in the jupiter OT model, but working with blocks of text instead of individual text operations

  # Excerpt from the paper:
  # "The general tool for handling conflicting messages is a function, xform,
  # that maps a pair of messages to the fixed up versions. We write
  # Xform(c, s) = { c', s' }
  # where c and s are the original client and server messages.
  # The messages c' and s' must have the property that if the client applies c
  # followed by s', and the server applies s followed by c', then the client and
  # server will wind up in the same final state."

  @type change() ::
          {
            :insert,
            position :: non_neg_integer(),
            text :: String.t()
          }
          | {
              :delete,
              position :: non_neg_integer(),
              amount :: non_neg_integer()
            }

  @spec reconcile(change(), change()) :: {change(), change()}

  def reconcile({:insert, position_1, text_1}, {:insert, position_2, text_2}) do
    if position_1 > position_2 do
      {
        {:insert, position_1 + String.length(text_2), text_1},
        {:insert, position_2, text_2}
      }
    else
      {
        {:insert, position_1, text_1},
        {:insert, position_2 + String.length(text_1), text_2}
      }
    end
  end

  # for simplicity's sake, if an insert is inside a delete, it is not done
  def reconcile({:insert, position_1, text_1}, {:delete, position_2, amount_2}) do
    if position_1 > position_2 do
      if position_1 >= position_2 + amount_2 do
        {
          {:insert, position_1 - amount_2, text_1},
          {:delete, position_2, amount_2}
        }
      else
        {
          {:insert, position_1, ""},
          {:delete, position_2, amount_2 + String.length(text_1)}
        }
      end
    else
      {
        {:insert, position_1, text_1},
        {:delete, position_2 + String.length(text_1), amount_2}
      }
    end
  end

  def reconcile({:delete, position_1, amount_1}, {:insert, position_2, text_2}) do
    {insert_prime, delete_prime} =
      reconcile({:insert, position_2, text_2}, {:delete, position_1, amount_1})

    {delete_prime, insert_prime}
  end

  def reconcile({:delete, position_1, amount_1}, {:delete, position_2, amount_2}) do
    left_1 = position_1
    right_1 = position_1 + amount_1
    left_2 = position_2
    right_2 = position_2 + amount_2

    overlap_start = max(left_1, left_2)
    overlap_end = min(right_1, right_2)
    overlap_area = overlap_end - overlap_start

    cond do
      overlap_area <= 0 ->
        if position_1 > position_2 do
          {
            {:delete, position_1 - amount_2, amount_1},
            {:delete, position_2, amount_2}
          }
        else
          {
            {:delete, position_1, amount_1},
            {:delete, position_2 - amount_1, amount_2}
          }
        end

      # left "eclipses" right
      left_1 <= left_2 && right_1 >= right_2 ->
        {
          {:delete, position_1, amount_1 - amount_2},
          {:delete, position_2, 0}
        }

      # right "eclipses" left
      left_1 > left_2 && right_1 < right_2 ->
        {
          {:delete, position_1, 0},
          {:delete, position_2, amount_2 - amount_1}
        }

      # overlap on one side
      left_1 > left_2 || right_1 < right_2 ->
        {
          {:delete, min(position_2, position_1), amount_1 - overlap_area},
          {:delete, min(position_2, position_1), amount_2 - overlap_area}
        }
    end
  end

  @spec clamp(change(), String.t()) :: change()
  def clamp(change, string) do
    string_length = String.length(string)

    case change do
      {:delete, position, amount} ->
        position = position |> min(string_length) |> max(0)
        amount = amount |> min(string_length - position) |> max(0)
        {:delete, position, amount}

      {:insert, position, text} ->
        position = position |> min(string_length) |> max(0)
        {:insert, position, text}
    end
  end
end
