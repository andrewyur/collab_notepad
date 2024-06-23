defmodule Mdc.Core.DocTreeTest do
  use ExUnit.Case

  alias Mdc.Core.DocTree

  test "tree_to_string" do
    node = {20, %{
      0 => {10, %{
        0 => "1234567890",
        1 => "0987654321"
      }},
      1 => "asdfghjklasdfghjkl"
    }}

    assert DocTree.tree_to_string(node) == "12345678900987654321asdfghjklasdfghjkl"
  end

  test "check_node_split1" do
    split = DocTree.check_node("123456789012345678901234567890")

    assert DocTree.is_internal?(split)
    assert DocTree.get_val(split) == 15
    assert DocTree.tree_to_string(split) == "123456789012345678901234567890"
  end

  test "check_node_split2" do
    node = {20, %{
      0 => "12345678901234567890",
      1 => "123456789012345678901234567890"
    }}

    split = DocTree.check_node(node)

    assert DocTree.is_internal?(split)
    assert DocTree.get_val(DocTree.get_right(split)) == 15
    assert DocTree.is_internal?(DocTree.get_right(split))
    assert DocTree.tree_to_string(split) == "12345678901234567890123456789012345678901234567890"
  end

  test "check_node_merge1" do
    node = {10, %{
      0 => "1234567890",
      1 => "1234567890",
    }}

    merge = DocTree.check_node(node)

    assert !DocTree.is_internal?(merge)
    assert DocTree.tree_to_string(merge) == "12345678901234567890"
  end

  test "check_node_merge2" do
    node = {10, %{
      0 => "1234567890",
      1 => {20, %{
        0 => "1234567890",
        1 => "1234567890",
      }}
    }}

    merge = DocTree.check_node(node)

    assert DocTree.is_internal?(merge)
    assert !DocTree.is_internal?(DocTree.get_right(merge))
    assert DocTree.tree_to_string(merge) == "123456789012345678901234567890"
  end

  test "recalc_vals" do
    tree = {10, %{
      0 => {20, %{
        0 => "1234567890",
        1 => "12345678901234567890",
      }},
      1 => {20, %{
        0 => "1234567890",
        1 => "1234567890",
      }}
    }}

    {correct_tree, tree_length} = DocTree.recalc_vals(tree)

    assert tree_length == 50
    assert DocTree.get_val(correct_tree) == 30
    assert DocTree.get_val(DocTree.get_left(correct_tree)) == 10
    assert DocTree.get_val(DocTree.get_right(correct_tree)) == 10
  end

  test "insert" do
    tree = {30, %{
      0 => {10, %{
        0 => "1234567890",
        1 => "12345678901234567890",
      }},
      1 => {10, %{
        0 => "1234567890",
        1 => "1234567890",
      }}
    }}

    correct_tree = {35, %{
      0 => {10, %{
        0 => "1234567890",
        1 => "1234567890123456789055555",
      }},
      1 => {10, %{
        0 => "1234567890",
        1 => "1234567890",
      }}
    }}

    {new_tree, diff} = DocTree.insert(tree, 30, "55555")

    assert new_tree == correct_tree
    assert DocTree.tree_to_string(correct_tree) == "1234567890123456789012345678905555512345678901234567890"
  end

  test "delete" do
    tree = {30, %{
      0 => {10, %{
        0 => "1234567890",
        1 => "12345678901234567890",
      }},
      1 => {10, %{
        0 => "1234567890",
        1 => "1234567890",
      }}
    }}

    correct_tree = {20, %{
      0 => {10, %{
        0 => "1234567890",
        1 => "1234567890",
      }},
      1 => {5, %{
        0 => "67890",
        1 => "1234567890",
      }}
    }}

    new_tree = DocTree.delete(tree, 20, 15)

    assert new_tree == correct_tree
    assert DocTree.tree_to_string(correct_tree) == "12345678901234567890678901234567890"
  end

  test "restructure" do
    tree = {40, %{
      0 => {10, %{
        0 => "12345678901234567890",
        1 => "123456789012345678901234567890",
      }},
      1 => {10, %{
        0 => "1234567890",
        1 => "1234567890",
      }}
    }}

    assert Mdc.Core.DocTree.restructure(tree) == {35, %{
      0 => {20, %{
        0 => "12345678901234567890",
        1 => "123456789012345"
      }},
      1 => {15, %{
        0 => "678901234567890",
        1 => "12345678901234567890"
      }}
    }}
  end
end
