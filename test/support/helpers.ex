defmodule Nc.Support.Helpers do
  @moduledoc """
  Helper functions for (defunct) tests
  """

  alias Nc.Core.Sync

  def apply_change(string, change) do
    case change do
      {:insert, position, text, _from} ->
        {front, back} = String.split_at(string, position)
        front <> text <> back

      {:delete, position, amount, _from} ->
        {front, rest} = String.split_at(string, position)
        {_, back} = String.split_at(rest, amount)
        front <> back

      nil ->
        string
    end
  end

  def apply_change_named(str, change, to) do
    if change == nil || elem(change, 3) == to do
      str
    else
      apply_change(str, change)
    end
  end

  def random_change(string, letter, from \\ nil) do
    position = :rand.uniform(String.length(string) + 1) - 1
    amount = :rand.uniform(String.length(string) + 1)

    case :rand.uniform(2) do
      1 -> {:delete, position, amount, from}
      2 -> {:insert, position, String.duplicate(letter, amount), from}
    end
  end

  def generate_change_list(string, from, length \\ nil) do
    0..(length || :rand.uniform(String.length(string) + 1))
    |> Enum.map(fn i ->
      random_change(string, <<65 + Integer.mod(i, 26)>>, from)
    end)
  end

  def apply_change_list(string, changes, to \\ nil) do
    reduction_function =
      if to == nil do
        &apply_change(&2, &1)
      else
        &apply_change_named(&2, &1, to)
      end

    Enum.reduce(changes, string, reduction_function)
  end

  def apply_and_clamp(string, changes) do
    {new_string, new_changes} =
      Enum.reduce(changes, {string, []}, fn change, {new_string, new_changes} ->
        change = Sync.clamp(change, new_string)
        new_string = apply_change(new_string, change)
        {new_string, [change | new_changes]}
      end)

    {new_string, Enum.reverse(new_changes)}
  end

  def get_relevant_changes(changelog, last_synced) do
    for {change, version} when version > last_synced <- changelog, do: change
  end

  def extend_changelog(changelog, new_changes) do
    new_changes =
      changelog ++
        Enum.zip(
          new_changes,
          Stream.iterate(elem(List.last(changelog, {0, 0}), 1) + 1, &(&1 + 1))
        )

    {elem(List.last(new_changes), 1), new_changes}
  end
end
