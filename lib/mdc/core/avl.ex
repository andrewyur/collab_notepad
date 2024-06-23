defmodule Mdc.Core.Avl do
  # AVL tree functionality

  def height(node) do
    case node do
      {_, map} ->
        1 + max(
          height(Map.fetch!(map, 0)),
          height(Map.fetch!(map, 1))
        )
      _string ->
        0
    end
  end

  def balance_factor(node) do
    case node do
      {_, map} ->
        height(Map.fetch!(map, 1)) - height(Map.fetch!(map, 0))
      _string ->
        0
    end
  end

  # call on this node  ->  X               Z
  #                       / \             / \
  #                     t1   Z    ->     X   t4
  #                         / \         / \
  #                      t23   t4     t1   t23

  # i am not sure how fast this is
  def rotate_left(x_node) do
    {x, x_tree} = x_node

    t1 = Map.fetch!(x_tree, 0)
    z_node = Map.fetch!(x_tree, 1)

    {z, z_tree} = z_node
    t23 = Map.fetch!(z_tree, 0)
    t4 = Map.fetch!(z_tree, 1)

    {z, %{
      0 => { x, %{0 => t1, 1 => t23}},
      1 => t4
    }}
  end

  # call on this node  ->  Z               X
  #                       / \             / \
  #                      X   t4   ->    t1   Z
  #                     / \                 / \
  #                   t1   t23           t23   t4

  # i am not sure how fast this is
  def rotate_right(z_node) do
    {z, z_tree} = z_node

    x_node = Map.fetch!(z_tree, 0)
    t4 = Map.fetch!(z_tree, 1)

    {x, x_tree} = x_node
    t1 = Map.fetch!(x_tree, 0)
    t23 = Map.fetch!(x_tree, 1)

    {x, %{
      0 => t1,
      1 => { z, %{0 => t23, 1 => t4}}
    }}
  end

  # call on this node  ->  X                       Y
  #                       / \                    /   \
  #                     t1   Z                 X       Z
  #                         / \      ->       / \     / \
  #                        Y   t4           t1   t2 t3   t4
  #                       / \
  #                     t2   t3

  def rotate_left_right(x_node) do
    {x, x_tree} = x_node

    t1 = Map.fetch!(x_tree, 0)
    z_node = Map.fetch!(x_tree, 1)

    z_node = rotate_right(z_node)

    x_node = {x, %{0 => t1, 1 => z_node}}

    rotate_left(x_node)
  end

  # call on this node  ->  Z                    Y
  #                       / \                 /   \
  #                      X   t4             X       Z
  #                     / \        ->      / \     / \
  #                   t1   Y             t1   t2 t3   t4
  #                       / \
  #                     t2   t3

  def rotate_right_left(z_node) do
    {z, z_tree} = z_node

    x_node = Map.fetch!(z_tree, 0)
    t4 = Map.fetch!(z_tree, 1)

    x_node = rotate_left(x_node)

    z_node = {z, %{0 => x_node, 1 => t4}}

    rotate_right(z_node)
  end

  # categorizes a node into 1 of 5 different cases
  # :balanced
  # :right_right
  # :left_left
  # :right_left
  # :left_right
  def categorize(tree) do

    balance_factor = balance_factor(tree)

    {_, map} = tree
    left_subtree = Map.fetch!(map, 0)
    right_subtree = Map.fetch!(map, 1)

    cond do
      abs(balance_factor) < 2 ->
        :balanced
      balance_factor <= -2 ->
        if balance_factor(left_subtree) < 0 do
          :left_left
        else
          :left_right
        end
      balance_factor >= 2 ->
        if balance_factor(right_subtree) > 0 do
          :right_right
        else
          :right_left
        end
    end
  end

  def balance(tree) do
    {tree, check_children} =
      case categorize(tree) do
        :balanced -> {tree, false}
        :left_left -> {rotate_right(tree), true}
        :right_right -> {rotate_left(tree), true}
        :left_right -> {rotate_right_left(tree), true}
        :right_left -> {rotate_left_right(tree), true}
      end

    if check_children do
      Mdc.Core.DocTree.apply_to_children(tree, &balance/1)
    else
      tree
    end
  end
end
