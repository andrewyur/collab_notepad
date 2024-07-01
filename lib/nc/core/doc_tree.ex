defmodule Nc.Core.DocTree do
  @moduledoc """
  AVL tree that stores the document in chunks, so that string manipulations are not operating on the entire document.
  internal nodes store length of their left child, so finding the right chunk from a global index is pretty easy
  leaf nodes store the actual strings
  insert & delete update the indexes of the tree, but do not keep the sizes of the chunks the same, so the restucture
  function must be used to split/merge chunks, and rebalance the tree, but should probably not be used frequently(on page reload?).
  because elixir is an immutable language, this should be relatively fast & space efficient because data is reused

  This is a really cool data structure, but is entirely overkill for this use case! oh well...
  """

  # the tests expect a chunk size of 20, which realistically is too small
  # figure out how to fix this later
  @chunk_size 20

  @type t() :: internal() | leaf()

  @type internal() :: {
    non_neg_integer(),
    %{ required(0) => t(), required(1) => t() }
  }

  @type leaf() :: String.t()

  @spec new(String.t()) :: t()
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

  # <> is slow, so this is only for tests.
  # the client will be sent some form of list or object, and then convert it on their own time
  @spec tree_to_string(t()) :: String.t()
  def tree_to_string(tree) do
    cond do
      is_bitstring(tree) ->
        tree
      is_bitstring(get_left(tree)) && is_bitstring(get_right(tree)) ->
        merge_internal(tree)
      true ->
        tree_to_string(get_left(tree)) <> tree_to_string(get_right(tree))
    end
  end

  @spec create_node(non_neg_integer(), t(), t()) :: internal()
  def create_node(val, left, right), do: {val, %{ 0=> left, 1 => right }}

  @spec is_internal?(t()) :: boolean()
  def is_internal?(n), do: !is_bitstring(n)

  @spec get_left(internal()) :: t()
  def get_left({_, map}), do: Map.fetch!(map, 0)

  @spec get_right(internal()) :: t()
  def get_right({_, map}), do: Map.fetch!(map, 1)

  @spec get_val(internal()) :: non_neg_integer()
  def get_val({val, _}), do: val

  @spec apply_to_children(internal(), (t() -> t())) :: internal()
  def apply_to_children({v, map}, fun) do
    {v, %{
      0 => fun.(Map.fetch!(map, 0)),
      1 => fun.(Map.fetch!(map, 1))
    }}
  end

  # text manipulation

  @spec insert(t(), non_neg_integer(), String.t()) :: t()
  def insert(tree, index, text) do
    {tree, _diff} = insert_p(tree, index, text)

    # eventually, should check if the tree needs to be rebalanced here

    tree
  end

  @spec insert_p(t(), non_neg_integer(), String.t()) :: { t(), non_neg_integer() }
  # this has to be public for the tests :(
  def insert_p(tree, index, text) do
    if is_internal?(tree) do
      tree_val = get_val(tree)
      if index > tree_val do
        {new_node, diff} = insert_p(get_right(tree), index - tree_val, text)

        {create_node(tree_val, get_left(tree), new_node), diff}
      else
        {new_node, diff} = insert_p(get_left(tree), index, text)

        {create_node(tree_val + diff, new_node, get_right(tree)), diff }
      end
    else
      {front, back} = String.split_at(tree, index)
      new_string = front <> text <> back

      {new_string, String.length(text)}
    end
  end

  @spec delete(t(), non_neg_integer(), non_neg_integer()) :: t()
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

  @spec split_leaf(leaf()) :: internal()
  def split_leaf(string) do
    text_len = String.length(string)
    section_len = div(text_len, 2)

    {front, back} = String.split_at(string, section_len)
    create_node(section_len, front, back)
  end

  @spec merge_internal(internal()) :: leaf()
  def merge_internal({_, map}) do
    Map.fetch!(map, 0) <> Map.fetch!(map, 1)
  end

  @spec fix_nodes(t()) :: t()
  def fix_nodes(node) do
    if is_internal?(node) do
      left = get_left(node)
      right = get_right(node)
      new_node = apply_to_children(node, &fix_nodes/1)

      if is_bitstring(left) && is_bitstring(right) && String.length(left) + String.length(right) <= @chunk_size do
        merge_internal(new_node)
      else
        new_node
      end
    else
      if String.length(node) > @chunk_size do
        split_leaf(node)
      else
        node
      end
    end
  end

  @spec recalc_vals(t()) :: {t(), non_neg_integer()}
  def recalc_vals(tree) do
    if is_internal?(tree) do
      {left, left_length} = recalc_vals(get_left(tree))
      {right, right_length} = recalc_vals(get_right(tree))
      {create_node(left_length, left, right), left_length + right_length}
    else
      {tree, String.length(tree)}
    end
  end

  @spec restructure(t()) :: t()
  def restructure(tree) do
    {new_tree, _} =

    # split & combine chunks where necessary
    fix_nodes(tree)
    #|> IO.inspect(label: "check")

    # balance the tree
    |> Nc.Core.Avl.balance()
    #|> IO.inspect(label: "balance")

    # recalculate index values
    |> recalc_vals()
    #|> IO.inspect(label: "vals")

    new_tree
  end

  defp eval_leaf_size(tree) do
    if is_internal?(tree) do
      {max_left, min_left} = eval_leaf_size(get_left(tree))
      {max_right, min_right} = eval_leaf_size(get_right(tree))

      {max(max_left, max_right), min(min_left, min_right)}
    else
      {String.length(tree),String.length(tree)}
    end
  end

  defp eval_tree_height(tree) do
    if is_internal?(tree) do
      {max_left, min_left} = eval_tree_height(get_left(tree))
      {max_right, min_right} = eval_tree_height(get_right(tree))

      {1 + max(max_left, max_right), 1 + min(min_left, min_right)}
    else
      {0, 0}
    end
  end

  # this doesn't need to be called every time an edit happens, leave it up to the host
  @spec restructure_if_necessary(t()) :: t()
  def restructure_if_necessary(tree) do
    {max_size, min_size} = eval_leaf_size(tree)
    {max_height, min_height } = eval_tree_height(tree)

    if max_size > min_size * 2 || max_height > min_height * 2 do
      restructure(tree)
    else
      tree
    end
  end
end
