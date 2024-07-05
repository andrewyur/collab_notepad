defmodule Nc.SyncTest do
  use ExUnit.Case, async: true

  alias Nc.Sync

  # these tests are as much to help me find situations i had not expected as to find bugs in my code

  def apply_change(string, change) do
    case change do
      {:insert, position, text} ->
        {front, back} = String.split_at(string, position)
        front <> text <> back

      {:delete, position, amount} ->
        {front, rest} = String.split_at(string, position)
        {_, back} = String.split_at(rest, amount)
        front <> back

      nil ->
        string
    end
  end

  def random_change(string, letter) do
    position = :rand.uniform(String.length(string) + 1) - 1
    amount = :rand.uniform(String.length(string))

    case :rand.uniform(2) do
      1 -> {:delete, position, amount}
      2 -> {:insert, position, String.duplicate(letter, amount)}
    end
  end

  # this has passed 1_000_000 iterations
  test "randomized test" do
    Enum.each(0..100, fn _ ->
      string = "12345678901234567890"

      change1 = random_change(string, "A")
      change2 = random_change(string, "B")

      change1 = Sync.clamp(change1, string)
      server = apply_change(string, change1)
      change2 = Sync.clamp(change2, string)
      client = apply_change(string, change2)

      {change1_p, change2_p} = Sync.reconcile(change1, change2)

      assert apply_change(server, change2_p) == apply_change(client, change1_p),
             inspect([change1, change2])
    end)
  end

  # this has passed 1_000_000 iterations
  test "randomized 1 2 compound divergence" do
    Enum.each(0..100, fn _ ->
      string = "12345678901234567890"

      o_change1 = random_change(string, "A")
      o_change2 = random_change(string, "B")
      o_change3 = random_change(string, "C")

      change3 = Sync.clamp(o_change3, string)
      server = apply_change(string, change3)

      change1 = Sync.clamp(o_change1, string)
      client = apply_change(string, change1)
      change2 = Sync.clamp(o_change2, client)
      client = apply_change(client, change2)

      {change1_p, change3_p} = Sync.reconcile(change1, change3)
      server = apply_change(server, change1_p)
      {change2_p, _change3_pp} = Sync.reconcile(change2, change3_p)
      server = apply_change(server, change2_p)

      {_change1_p, change3_p} = Sync.reconcile(change1, change3)
      {_change2_p, change3_pp} = Sync.reconcile(change2, change3_p)
      client = apply_change(client, change3_pp)

      assert client == server, inspect([client, server, o_change1, o_change2, o_change3])
    end)
  end

  test "insert delete 1" do
    string = "12345678901234567890"

    change1 = {:insert, 12, "AA"}
    change2 = {:delete, 10, 8}

    assert apply_change(string, change1) == "123456789012AA34567890"
    assert apply_change(string, change2) == "123456789090"

    assert Sync.reconcile(change1, change2) == {
             nil,
             {:delete, 10, 10}
           }

    server = apply_change(string, change1)
    client = apply_change(string, change2)

    {change1_p, change2_p} = Sync.reconcile(change1, change2)

    assert apply_change(server, change2_p) == apply_change(client, change1_p),
           inspect([client, server, change1, change2])
  end

  test "1 2 compound divergence" do
    # trying to mimic the interaction between the server and the client

    # server and client start off synchronized
    server = "1234567890!@#$%^&*()"
    client = "1234567890!@#$%^&*()"

    [change1, change2, change3] = [
      {:delete, 7, 13},
      {:insert, 7, "BBBBBBBBBBBBBB"},
      {:insert, 20, "CCCCCCCCCCCCCCC"}
    ]

    # server applies a change
    change3 = Sync.clamp(change3, server)
    server = apply_change(server, change3)

    # client has applied 2 local changes
    change1 = Sync.clamp(change1, client)
    client = apply_change(client, change1)
    change2 = Sync.clamp(change2, client)
    client = apply_change(client, change2)

    # it is important that these changes are clamped and applied before they are sent over

    # client then recieves the server change, and recognizes it was sent before its local changes were recieved.
    # client reconciles the incoming change against its unacknowledged changes, and then applies it

    {_change1_p, change3_p} = Sync.reconcile(change1, change3)
    {_change2_p, change3_pp} = Sync.reconcile(change2, change3_p)

    client = apply_change(client, change3_pp)

    # client then sends its changes to server, and server does the same.
    {change1_p, change3_p} = Sync.reconcile(change1, change3)
    server = apply_change(server, change1_p)

    {change2_p, _change3_pp} = Sync.reconcile(change2, change3_p)
    server = apply_change(server, change2_p)

    # the client and server should now have identical documents!
    assert server == client
  end

  test "2 3 compound divergence" do
    string = "1234567890!@#$%^&*()"

    server_changes = [
      {:delete, 8, 12},
      {:insert, 8, "AAAAAAAAAA"}
    ]

    client_changes = [
      {:delete, 11, 9},
      {:insert, 11, "AAAAAAAAAA"},
      {:insert, 20, "BBBBBB"}
    ]

    {server, server_changes} =
      Enum.reduce(server_changes, {string, []}, fn change, {server, new_changes} ->
        change = Sync.clamp(change, server)
        server = apply_change(server, change)
        {server, [change | new_changes]}
      end)

    server_changes = Enum.reverse(server_changes)

    {client, client_changes} =
      Enum.reduce(client_changes, {string, []}, fn change, {client, new_changes} ->
        change = Sync.clamp(change, client)
        client = apply_change(client, change)
        {client, [change | new_changes]}
      end)

    client_changes = Enum.reverse(client_changes)

    [
      s_change1,
      s_change2
    ] = server_changes

    [
      c_change1,
      c_change2,
      c_change3
    ] = client_changes

    # This looks like it could be improved with memoization or dp of some form

    {s_change1_p, c_change1_p} = Sync.reconcile(s_change1, c_change1)
    {s_change2_p, c_change1_pp} = Sync.reconcile(s_change2, c_change1_p)
    server = apply_change(server, c_change1_pp)

    {s_change1_pp, c_change2_p} = Sync.reconcile(s_change1_p, c_change2)
    {s_change2_pp, c_change2_pp} = Sync.reconcile(s_change2_p, c_change2_p)
    server = apply_change(server, c_change2_pp)

    {s_change1_ppp, c_change3_p} = Sync.reconcile(s_change1_pp, c_change3)
    {s_change2_ppp, c_change3_pp} = Sync.reconcile(s_change2_pp, c_change3_p)
    server = apply_change(server, c_change3_pp)

    #

    {s_change1_p, c_change1_p} = Sync.reconcile(s_change1, c_change1)
    {s_change1_pp, c_change2_p} = Sync.reconcile(s_change1_p, c_change2)
    {s_change1_ppp, c_change3_p} = Sync.reconcile(s_change1_pp, c_change3)

    client = apply_change(client, s_change1_ppp)

    {s_change2_p, c_change1_pp} = Sync.reconcile(s_change2_p, c_change1_p)
    {s_change2_pp, c_change2_pp} = Sync.reconcile(s_change2_p, c_change2_p)
    {s_change2_ppp, c_change3_pp} = Sync.reconcile(s_change2_pp, c_change3_p)

    client = apply_change(client, s_change2_ppp)

    assert server == client
  end

  test "commutative test" do
    i1 = {:insert, 8, "AAAAAAAAAA"}
    i2 = {:insert, 8, "AAAAAAAAAA"}

    {i1_p1, i2_p1} = Sync.reconcile(i1, i2)
    {i2_p2, i1_p2} = Sync.reconcile(i2, i1)

    assert i1_p1 == i1_p2
    assert i2_p1 == i2_p2
  end

  def generate_change_list(string, length \\ nil) do
    0..:rand.uniform(length || String.length(string))
    |> Enum.map(fn i ->
      random_change(string, <<64 + i>>)
    end)
  end

  defp reconcile_single_change(current_changelog_change, {reconciled_change, new_changelog}) do
    {new_current_changelog_change, new_reconciled_change} =
      Sync.reconcile(current_changelog_change, reconciled_change)

    {new_reconciled_change, [new_current_changelog_change | new_changelog]}
  end

  defp reconcile_all_changes(incoming_change, {current_string, current_changelog}) do
    {reconciled_change, new_changelog} =
      Enum.reduce(current_changelog, {incoming_change, []}, &reconcile_single_change/2)

    new_changelog = Enum.reverse(new_changelog)
    new_string = apply_change(current_string, reconciled_change)
    {new_string, new_changelog}
  end

  def reconcile_changes(string, incoming, changelog) do
    {reconciled_string, _reconciled_changelog} =
      Enum.reduce(incoming, {string, changelog}, &reconcile_all_changes/2)

    reconciled_string
  end

  test "n n compound divergence" do
    # testing that set of 1st degree divergences of any length can be resolved
    string = "1234567890!@#$%^&*()"

    server_changes = [
      {:delete, 9, 11},
      {:insert, 9, "A"}
    ]

    client_changes = [
      {:insert, 9, "@@@@@@@@@@@@@@@@@@@@"},
      {:insert, 4, "AAAAAAAAA"},
      {:insert, 0, "BBBBBBBBBBB"}
    ]

    {server, server_changes} =
      Enum.reduce(server_changes, {string, []}, fn change, {server, new_changes} ->
        change = Sync.clamp(change, server)
        server = apply_change(server, change)
        {server, [change | new_changes]}
      end)

    server_changes = Enum.reverse(server_changes)

    {client, client_changes} =
      Enum.reduce(client_changes, {string, []}, fn change, {client, new_changes} ->
        change = Sync.clamp(change, client)
        client = apply_change(client, change)
        {client, [change | new_changes]}
      end)

    client_changes = Enum.reverse(client_changes)

    assert reconcile_changes(client, server_changes, client_changes) ==
             reconcile_changes(server, client_changes, server_changes)
  end

  @tag timeout: :infinity
  # this test has passed 1_000_000 iterations
  test "automated n n compound divergence" do
    changelog_length = nil

    Enum.each(0..10, fn _ ->
      string = "1234567890!@#$%^&*()"

      server_changes = generate_change_list(string, changelog_length)

      client_changes = generate_change_list(string, changelog_length)

      {server, server_changes} =
        Enum.reduce(server_changes, {string, []}, fn change, {server, new_changes} ->
          change = Sync.clamp(change, server)
          server = apply_change(server, change)
          {server, [change | new_changes]}
        end)

      server_changes = Enum.reverse(server_changes)

      {client, client_changes} =
        Enum.reduce(client_changes, {string, []}, fn change, {client, new_changes} ->
          change = Sync.clamp(change, client)
          client = apply_change(client, change)
          {client, [change | new_changes]}
        end)

      client_changes = Enum.reverse(client_changes)

      new_client = reconcile_changes(client, server_changes, client_changes)
      new_server = reconcile_changes(server, client_changes, server_changes)

      if new_client != new_server do
        IO.inspect({client_changes, server_changes})
      end

      assert new_client == new_server
    end)
  end

  test "n ^ n compound divergence" do
    # testing that set of any degree of divergences of any length can be resolved
  end
end
