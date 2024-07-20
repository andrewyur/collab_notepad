defmodule Nc.Core.Sync do
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
            text :: String.t(),
            from :: any()
          }
          | {
              :delete,
              position :: non_neg_integer(),
              amount :: non_neg_integer(),
              from :: any()
            }
          | nil

  @spec reconcile(change(), change()) :: {change(), change()}

  # this function must be commutative!
  def reconcile({:insert, position_1, text_1, from_1}, {:insert, position_2, text_2, from_2}) do
    cond do
      position_1 > position_2 || (position_1 == position_2 && text_1 > text_2) ||
          (position_1 == position_2 && text_1 == text_2 && from_1 > from_2) ->
        {
          {:insert, position_1 + String.length(text_2), text_1, from_1},
          {:insert, position_2, text_2, from_2}
        }

      position_1 < position_2 || (position_1 == position_2 && text_1 < text_2) ||
          (position_1 == position_2 && text_1 == text_2 && from_1 < from_2) ->
        {
          {:insert, position_1, text_1, from_1},
          {:insert, position_2 + String.length(text_1), text_2, from_2}
        }

      # the case for identical inputs
      # this is actually has the benefit of cancelling out changes coming from the same source
      true ->
        {nil, nil}
    end
  end

  # for simplicity's sake, if an insert is inside a delete, it is nullified
  def reconcile({:insert, position_1, text_1, from_1}, {:delete, position_2, amount_2, from_2}) do
    if position_1 > position_2 do
      if position_1 >= position_2 + amount_2 do
        {
          {:insert, position_1 - amount_2, text_1, from_1},
          {:delete, position_2, amount_2, from_2}
        }
      else
        {
          nil,
          {:delete, position_2, amount_2 + String.length(text_1), from_2}
        }
      end
    else
      {
        {:insert, position_1, text_1, from_1},
        {:delete, position_2 + String.length(text_1), amount_2, from_2}
      }
    end
  end

  def reconcile({:delete, position_1, amount_1, from_1}, {:insert, position_2, text_2, from_2}) do
    {insert_prime, delete_prime} =
      reconcile({:insert, position_2, text_2, from_2}, {:delete, position_1, amount_1, from_1})

    {delete_prime, insert_prime}
  end

  def reconcile({:delete, position_1, amount_1, from_1}, {:delete, position_2, amount_2, from_2}) do
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
            {:delete, position_1 - amount_2, amount_1, from_1},
            {:delete, position_2, amount_2, from_2}
          }
        else
          {
            {:delete, position_1, amount_1, from_1},
            {:delete, position_2 - amount_1, amount_2, from_2}
          }
        end

      # left "eclipses" right
      left_1 <= left_2 && right_1 >= right_2 ->
        {
          {:delete, position_1, amount_1 - amount_2, from_1},
          nil
        }

      # right "eclipses" left
      left_1 >= left_2 && right_1 <= right_2 ->
        {
          nil,
          {:delete, position_2, amount_2 - amount_1, from_2}
        }

      # overlap on one side
      left_1 > left_2 || right_1 < right_2 ->
        {
          {:delete, min(position_2, position_1), amount_1 - overlap_area, from_1},
          {:delete, min(position_2, position_1), amount_2 - overlap_area, from_2}
        }
    end
  end

  def reconcile(nil, change) do
    {
      nil,
      change
    }
  end

  def reconcile(change, nil) do
    {
      change,
      nil
    }
  end

  @spec clamp(change(), String.t()) :: change()
  def clamp(change, string) do
    string_length = String.length(string)

    case change do
      {:delete, position, amount, from} ->
        position = position |> min(string_length) |> max(0)
        amount = amount |> min(string_length - position) |> max(0)

        if amount <= 0 do
          nil
        else
          {:delete, position, amount, from}
        end

      {:insert, position, text, from} ->
        position = position |> min(string_length) |> max(0)
        {:insert, position, text, from}
    end
  end

  def reconcile_against(incoming_list, outgoing_list) do
    reconcile_single_change = fn outgoing_change, {incoming_change, new_outgoing_list} ->
      {new_outgoing_change, new_incoming_change} =
        reconcile(outgoing_change, incoming_change)

      {new_incoming_change, [new_outgoing_change | new_outgoing_list]}
    end

    reconcile_all_changes = fn incoming_change, {new_incoming_list, current_outgoing_list} ->
      {new_incoming_change, new_outgoing_list} =
        Enum.reduce(current_outgoing_list, {incoming_change, []}, reconcile_single_change)

      new_outgoing_list = Enum.reverse(new_outgoing_list)
      {[new_incoming_change | new_incoming_list], new_outgoing_list}
    end

    {new_incoming_list, new_outgoing_list} =
      Enum.reduce(incoming_list, {[], outgoing_list}, reconcile_all_changes)

    {Enum.reverse(new_incoming_list), new_outgoing_list}
  end
end
