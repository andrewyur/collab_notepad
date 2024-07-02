defmodule Nc.Sync.ReconcileTest do
  use ExUnit.Case

  alias Nc.Sync.Reconcile

  def apply_change(string, change) do
    case change do
      {:insert, position, text} ->
        {front, back} = String.split_at(string, position)
        front <> text <> back

      {:delete, position, amount} ->
        {front, rest} = String.split_at(string, position)
        {_, back} = String.split_at(rest, amount)
        front <> back
    end
  end

  def apply_and_assert(string, change1, change2) do
    string1 = apply_change(string, change1)
    string2 = apply_change(string, change2)

    {change1_prime, change2_prime} = Reconcile.reconcile(change1, change2)

    assert apply_change(string1, change2_prime) == apply_change(string2, change1_prime),
           inspect([change1, change2])
  end

  # this has passed 1_000_000 iterations
  test "randomized test" do
    Enum.each(0..1_000_000, fn _ ->
      starting_string = "12345678901234567890"

      position_1 = :rand.uniform(String.length(starting_string) + 1) - 1
      position_2 = :rand.uniform(String.length(starting_string) + 1) - 1

      amount_1 = :rand.uniform(10)
      amount_2 = :rand.uniform(10)

      case :rand.uniform(4) do
        # ii
        1 ->
          apply_and_assert(
            starting_string,
            {:insert, position_1, String.duplicate("A", amount_1)},
            {:insert, position_2, String.duplicate("B", amount_2)}
          )

        # id
        2 ->
          apply_and_assert(
            starting_string,
            {:insert, position_1, String.duplicate("A", amount_1)},
            {:delete, position_2, amount_2}
          )

        # di
        3 ->
          apply_and_assert(
            starting_string,
            {:delete, position_1, amount_1},
            {:insert, position_2, String.duplicate("B", amount_2)}
          )

        # dd
        4 ->
          apply_and_assert(
            starting_string,
            {:delete, position_1, amount_1},
            {:delete, position_2, amount_2}
          )
      end
    end)
  end

  test "insert delete 1" do
    string = "12345678901234567890"

    change1 = {:insert, 12, "AA"}
    change2 = {:delete, 10, 8}

    assert apply_change(string, change1) == "123456789012AA34567890"
    assert apply_change(string, change2) == "123456789090"

    assert Reconcile.reconcile(change1, change2) == {
             {:insert, 12, ""},
             {:delete, 10, 10}
           }

    apply_and_assert(string, change1, change2)
  end
end
