defmodule Nc.Core.AvlTest do
  use ExUnit.Case

  @left {:z,
         %{
           0 =>
             {:x,
              %{
                0 => :t1,
                1 => :t23
              }},
           1 => :t4
         }}
  @right {:x,
          %{
            0 => :t1,
            1 =>
              {:z,
               %{
                 0 => :t23,
                 1 => :t4
               }}
          }}
  @balanced {:y,
             %{
               0 =>
                 {:x,
                  %{
                    0 => :t1,
                    1 => :t2
                  }},
               1 =>
                 {:z,
                  %{
                    0 => :t3,
                    1 => :t4
                  }}
             }}
  @right_left {:x,
               %{
                 0 => :t1,
                 1 =>
                   {:z,
                    %{
                      0 =>
                        {:y,
                         %{
                           0 => :t2,
                           1 => :t3
                         }},
                      1 => :t4
                    }}
               }}
  @left_right {:z,
               %{
                 0 =>
                   {:x,
                    %{
                      0 => :t1,
                      1 =>
                        {:y,
                         %{
                           0 => :t2,
                           1 => :t3
                         }}
                    }},
                 1 => :t4
               }}
  @left_left {:z,
              %{
                0 =>
                  {:y,
                   %{
                     0 =>
                       {:x,
                        %{
                          0 => :t1,
                          1 => :t2
                        }},
                     1 => :t3
                   }},
                1 => :t4
              }}
  @right_right {:x,
                %{
                  0 => :t1,
                  1 =>
                    {:y,
                     %{
                       0 => :t2,
                       1 =>
                         {:z,
                          %{
                            0 => :t3,
                            1 => :t4
                          }}
                     }}
                }}

  test "rotate_left" do
    assert Nc.Core.Avl.rotate_left(@right) == @left
  end

  test "rotate_right" do
    assert Nc.Core.Avl.rotate_right(@left) == @right
  end

  test "rotate_left_right" do
    assert Nc.Core.Avl.rotate_left_right(@right_left) == @balanced
  end

  test "rotate_right_left" do
    assert Nc.Core.Avl.rotate_right_left(@left_right) == @balanced
  end

  test "categorize_balanced" do
    assert Nc.Core.Avl.categorize(@balanced) == :balanced
  end

  test "categorize_left" do
    assert Nc.Core.Avl.categorize(@left) == :balanced
  end

  test "categorize_right" do
    assert Nc.Core.Avl.categorize(@right) == :balanced
  end

  test "categorize_left_left" do
    assert Nc.Core.Avl.categorize(@left_left) == :left_left
  end

  test "categorize_right_right" do
    assert Nc.Core.Avl.categorize(@right_right) == :right_right
  end

  test "categorize_left_right" do
    assert Nc.Core.Avl.categorize(@left_right) == :left_right
  end

  test "categorize_right_left" do
    assert Nc.Core.Avl.categorize(@right_left) == :right_left
  end

  test "balance_left" do
    assert Nc.Core.Avl.balance(@left) == @left
  end

  test "balance_right" do
    assert Nc.Core.Avl.balance(@right) == @right
  end

  test "balance_balanced" do
    assert Nc.Core.Avl.balance(@balanced) == @balanced
  end

  test "balance_right_right" do
    assert Nc.Core.Avl.balance(@right_right) == @balanced
  end

  test "balance_right_left" do
    assert Nc.Core.Avl.balance(@right_left) == @balanced
  end

  test "balance_left_right" do
    assert Nc.Core.Avl.balance(@left_right) == @balanced
  end
end
