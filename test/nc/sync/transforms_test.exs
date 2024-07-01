defmodule Nc.Sync.TransformsTest do
  use ExUnit.Case
  alias Nc.Sync.Transforms

# Insert Insert outgoing

  test "outgoing ii before" do
    assert Transforms.transform_outgoing({:insert, 10, "testing"}, {:insert, 5, "testing2"})
      == {:insert, 18, "testing"}
  end

  test "outgoing ii after" do
    assert Transforms.transform_outgoing({:insert, 5, "testing2"}, {:insert, 10, "testing"})
      == {:insert, 5, "testing2"}
  end

# Insert Delete outgoing

  test "outgoing id before" do
    assert Transforms.transform_outgoing({:insert, 5, "testing2"}, {:delete, 4, 2})
      == {:insert, 3, "testing2"}
  end

  test "outgoing id after" do
    assert Transforms.transform_outgoing({:insert, 5, "testing2"}, {:delete, 7, 5})
      == {:insert, 5, "testing2"}
  end

  test "outgoing id negative" do
    assert Transforms.transform_outgoing({:insert, 5, "testing2"}, {:delete, 0, 12})
      == {:insert, 0, "testing2"}
  end

  # Delete Insert outgoing

  test "outgoing di before" do
    assert Transforms.transform_outgoing({:delete, 7, 5}, {:insert, 5, "testing2"})
    == {:delete, 15, 5}
  end

  test "outgoing di between" do
    assert Transforms.transform_outgoing({:delete, 4, 2}, {:insert, 5, "testing2"})
      == {:delete, 4, 10}
  end

  test "outgoing di after" do
    assert Transforms.transform_outgoing({:delete, 4, 2}, {:insert, 10, "testing"})
    == {:delete, 4, 2}
  end

  # Delete Delete outgoing

  test "outgoing dd before" do
    assert Transforms.transform_outgoing({:delete, 7, 5}, {:delete, 4, 2})
      == {:delete, 5, 5}
  end

  test "outgoing dd after" do
    assert Transforms.transform_outgoing({:delete, 4, 2}, {:delete, 7, 5})
      == {:delete, 4, 2}
  end

  test "outgoing dd negative" do
    assert Transforms.transform_outgoing({:delete, 4, 2}, {:delete, 0, 12})
      == {:delete, 0, 0}
  end

  test "outgoing dd overlap before" do
    assert Transforms.transform_outgoing({:delete, 4, 2}, {:delete, 3, 2})
      == {:delete, 3, 1}
  end

  test "outgoing dd overlap after" do
    assert Transforms.transform_outgoing({:delete, 4, 2}, {:delete, 5, 5})
      == {:delete, 4, 1}
  end

  test "outgoing dd overlap all" do
    assert Transforms.transform_outgoing({:delete, 4, 2}, {:delete, 3, 4})
      == {:delete, 3, 0}
  end

  # Insert Insert incoming

  test "incoming ii before" do
    assert Transforms.transform_incoming({:insert, 5, "testing2"}, {:insert, 10, "testing"})
    == {:insert, 5, "testing2"}
  end

  test "incoming ii after" do
    assert Transforms.transform_incoming({:insert, 10, "testing"}, {:insert, 5, "testing2"})
    == {:insert, 18, "testing"}
  end

  # Insert Delete incoming

  test "incoming id before" do
    assert Transforms.transform_incoming({:insert, 5, "testing2"}, {:delete, 0, 4})
    == {:insert, 1, "testing2"}
  end

    test "incoming id after" do
      assert Transforms.transform_incoming({:insert, 5, "testing2"}, {:delete, 7, 5})
      == {:insert, 5, "testing2"}
    end

  test "incoming id eclipse" do
    assert Transforms.transform_incoming({:insert, 5, "testing2"}, {:delete, 4, 2})
      == nil
  end

  # Delete Insert incoming

  test "incoming di before" do
    assert Transforms.transform_incoming({:delete, 7, 5}, {:insert, 5, "testing2"})
    == {:delete, 15, 5}
  end

  test "incoming di between" do
    assert Transforms.transform_incoming({:delete, 4, 2}, {:insert, 5, "testing2"})
      == [{:delete, 4, 1}, {:delete, 13, 1}]
  end

  test "incoming di after" do
    assert Transforms.transform_incoming({:delete, 4, 2}, {:insert, 10, "testing"})
    == {:delete, 4, 2}
  end

  # Delete Delete incoming

  test "incoming dd before" do
    assert Transforms.transform_incoming({:delete, 7, 5}, {:delete, 4, 2})
      == {:delete, 5, 5}
  end

  test "incoming dd after" do
    assert Transforms.transform_incoming({:delete, 4, 2}, {:delete, 7, 5})
      == {:delete, 4, 2}
  end

  test "incoming dd overlap before" do
    assert Transforms.transform_incoming({:delete, 4, 2}, {:delete, 3, 2})
      == {:delete, 4, 1}
  end

  test "incoming dd overlap after" do
    assert Transforms.transform_incoming({:delete, 4, 2}, {:delete, 5, 5})
      == {:delete, 4, 1}
  end

  test "incoming dd eclipse" do
    assert Transforms.transform_incoming({:delete, 4, 2}, {:delete, 3, 4})
      == nil
  end

  test "incoming dd split" do
    assert Transforms.transform_incoming({:delete, 4, 4}, {:delete, 5, 2})
      == {:delete, 4, 2}
  end

# Misc

  test "test 1" do
    assert Transforms.transform_outgoing({:delete, 0, 10}, {:insert, 0, "TESTING..."}) == {:delete, 0, 20}
  end


end
