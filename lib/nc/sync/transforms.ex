defmodule Nc.Sync.Transforms do
  alias Nc.Servers.DocServer

  @doc """
  the transform function follows the format:
    transform(request_to_be_transformed, past_change)
  """

  @spec transform_outgoing(DocServer.change(), DocServer.change()) :: DocServer.change()

  # where the change on the left is happening after the changes on the right

  def transform_outgoing({:insert, position_1, text_1}, {:insert, position_2, text_2}) do
    if position_1 <= position_2 do
      {:insert, position_1, text_1}
    else
      {:insert, position_1 + String.length(text_2), text_1}
    end
  end

  def transform_outgoing({:insert, position_1, text_1}, {:delete, position_2, amount_2}) do
    if position_1 <= position_2 do
      {:insert, position_1, text_1}
    else
      {:insert, max(position_1 - amount_2, 0), text_1}
    end
  end

  def transform_outgoing({:delete, position_1, amount_1}, {:insert, position_2, text_2}) do
    amount_2 = String.length(text_2)

    position_3 = if position_2 >= position_1 do
      position_1
    else
      position_1 + amount_2
    end

    amount_3 = if position_1 <= position_2 && position_2 <= position_1 + amount_1 do
      amount_1 + amount_2
    else
      amount_1
    end

    {:delete, max(0, position_3), max(0, amount_3)}
  end

  def transform_outgoing({:delete, position_1, amount_1}, {:delete, position_2, amount_2}) do

    position_3 = if position_1 <= position_2 do
      position_1
    else
      max(0, max(position_1 - amount_2, position_2))
    end

    left_bound_1 = position_1
    right_bound_1 = position_1 + amount_1
    left_bound_2 = position_2
    right_bound_2 = position_2 + amount_2

    overlap_start = max(left_bound_1, left_bound_2)
    overlap_end = min(right_bound_1, right_bound_2)
    overlap_area = overlap_end - overlap_start

    amount_3 = if overlap_area <= 0 do
      amount_1
    else
      amount_1 - overlap_area
    end

    {:delete, max(0, position_3), max(0, amount_3)}
  end

  @spec transform_incoming(DocServer.change(), DocServer.change()) :: [DocServer.change()] | DocServer.change() | nil

  # where the change on the left has happened before the change on the right

  def transform_incoming({:insert, position_1, text_1}, {:insert, position_2, text_2}) do
    if position_1 <= position_2 do
      {:insert, position_1, text_1}
    else
      {:insert, max(position_1 + String.length(text_2), 0), text_1}
    end
  end

  def transform_incoming({:insert, position_1, text_1}, {:delete, position_2, amount_2}) do
    if position_1 <= position_2 do
      {:insert, position_1, text_1}
    else
      if position_1 <= position_2 + amount_2 do
        nil
      else
        {:insert, max(position_1 - amount_2, 0), text_1}
      end
    end
  end

  def transform_incoming({:delete, position_1, amount_1}, {:insert, position_2, text_2}) do
    if position_1 + amount_1 <= position_2 do
      {:delete, position_1, amount_1}
    else
      if position_1 <= position_2 do
        [
          {:delete, position_1, position_2 - position_1},
          {:delete, position_2 + String.length(text_2), amount_1 - (position_2 - position_1)},
        ]
      else
        {:delete, position_1 + String.length(text_2), amount_1}
      end
    end
  end

  def transform_incoming({:delete, position_1, amount_1}, {:delete, position_2, amount_2}) do

    left_bound_1 = position_1
    right_bound_1 = position_1 + amount_1
    left_bound_2 = position_2
    right_bound_2 = position_2 + amount_2

    overlap_start = max(left_bound_1, left_bound_2)
    overlap_end = min(right_bound_1, right_bound_2)
    overlap_area = overlap_end - overlap_start

    if overlap_area > 0 do
      cond do
        # left
        left_bound_1 < left_bound_2 && right_bound_1 <= right_bound_2 ->
          {:delete, position_1, amount_1 - overlap_area}
        # right
        left_bound_1 >= left_bound_2 && right_bound_1 > right_bound_2 ->
          {:delete, position_1, amount_1 - overlap_area}
        # eclipsed
        left_bound_1 >= left_bound_2 && right_bound_1 <= right_bound_2 ->
          nil
        # split
        left_bound_1 < left_bound_2 && right_bound_1 > right_bound_2 ->
            {:delete, position_1, amount_1 - overlap_area}
      end
    else
      if position_1 < position_2 do
        {:delete, position_1, amount_1}
      else
        {:delete, position_1 - amount_2, amount_1}
      end
    end
  end
end
