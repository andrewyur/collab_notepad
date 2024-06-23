defmodule Mdc.Core.DocTree do
  # AVL tree that stores the document in chunks, so that string manipulations are not operating on the entire document.
  # internal nodes store length of their left child, so finding the right chunk from a global index is pretty easy
  # leaf nodes store the actual strings
  # insert & delete update the indexes of the tree, but do not keep the sizes of the chunks the same, so the restucture
  # function must be used to split/merge chunks, and rebalance the tree, but should probably not be used frequently(on page reload?).
  # because elixir is an immutable language, this should be relatively fast & space efficient because data is reused

  @chunk_size 20

  def new(full_text) do
    text_len = String.length(full_text)

    if text_len <= @chunk_size do
      full_text
    else
      section_len = div(text_len, 2)
      {front, back} = String.split_at(full_text, section_len)
      create_node(section_len, new(front), new(back))
    end
  end

  # Tree utility

  def tree_to_string(tree) do
    cond do
      is_bitstring(tree) ->
        tree
      is_bitstring(get_left(tree)) && is_bitstring(get_right(tree)) ->
        combine_nodes(tree)
      true ->
        tree_to_string(get_left(tree)) <> tree_to_string(get_right(tree))
    end
  end

  def create_node(val, left, right), do: {val, %{ 0=> left, 1 => right }}

  def is_internal?(n), do: !is_bitstring(n)

  def get_left({_, map}), do: Map.fetch!(map, 0)
  def get_right({_, map}), do: Map.fetch!(map, 1)
  def get_val({val, _}), do: val

  def apply_to_children({v, map}, fun) do
    {v, %{
      0 => fun.(Map.fetch!(map, 0)),
      1 => fun.(Map.fetch!(map, 1))
    }}
  end

  # text manipulation

  def insert(tree, index, text) do
    if is_internal?(tree) do
      tree_val = get_val(tree)
      if index > tree_val do
        {new_node, diff} = insert(get_right(tree), index - tree_val, text)

        {create_node(tree_val, get_left(tree), new_node), diff}
      else
        {new_node, diff} = insert(get_left(tree), index, text)

        {create_node(tree_val + diff, new_node, get_right(tree)), diff }
      end
    else
      {front, back} = String.split_at(tree, index)
      new_string = front <> text <> back

      {new_string, String.length(text)}
    end
  end

  def delete(tree, index, amount) do
    if is_internal?(tree) do
      tree_val = get_val(tree)

      if index > tree_val do
        new_node = delete(get_right(tree), index - tree_val, amount)

        create_node(tree_val, get_left(tree), new_node)
      else
        if index + amount > tree_val do
          diff = (index + amount) - tree_val
          new_left = delete(get_left(tree), index, amount - diff)
          new_right = delete(get_right(tree), 0, diff)

          create_node(tree_val - (amount - diff), new_left, new_right )
        else
          new_node = delete(get_left(tree), index, amount)

          create_node(tree_val - amount, new_node, get_right(tree))
        end
      end
    else
      {front, rest} = String.split_at(tree, index)
      {_ , back} = String.split_at(rest, amount)
      front <> back
    end
  end

  # tree structure

  def split_node(string) do
    text_len = String.length(string)
    section_len = div(text_len, 2)

    {front, back} = String.split_at(string, section_len)
    create_node(section_len, front, back)
  end

  def combine_nodes({_, map}) do
    Map.fetch!(map, 0) <> Map.fetch!(map, 1)
  end

  def check_node(node) do
    if is_internal?(node) do
      left = get_left(node)
      right = get_right(node)
      new_node = apply_to_children(node, &check_node/1)

      if is_bitstring(left) && is_bitstring(right) && String.length(left) + String.length(right) <= @chunk_size do
        combine_nodes(new_node)
      else
        new_node
      end
    else
      if String.length(node) > @chunk_size do
        split_node(node)
      else
        node
      end
    end
  end

  def recalc_vals(tree) do
    if is_internal?(tree) do
      {left, left_length} = recalc_vals(get_left(tree))
      {right, right_length} = recalc_vals(get_right(tree))
      {create_node(left_length, left, right), left_length + right_length}
    else
      {tree, String.length(tree)}
    end
  end

  def restructure(tree) do
    {new_tree, _} =

    # split & combine chunks where necessary
    check_node(tree)
    #|> IO.inspect(label: "check")

    # balance the tree
    |> Mdc.Core.Avl.balance()
    #|> IO.inspect(label: "balance")

    # recalculate index values
    |> recalc_vals()
    #|> IO.inspect(label: "vals")

    new_tree
  end
end
