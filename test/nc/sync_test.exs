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
  test "randomized compound divergence" do
    Enum.each(0..1_000_000, fn _ ->
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
             {:insert, 12, ""},
             {:delete, 10, 10}
           }

    server = apply_change(string, change1)
    client = apply_change(string, change2)

    {change1_p, change2_p} = Sync.reconcile(change1, change2)

    assert apply_change(server, change2_p) == apply_change(client, change1_p),
           inspect([client, server, change1, change2])
  end

  test "compound divergence" do
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
    # assert server == "1234567890!@#$%^&*()CCCCCCCCCCCCCCC"

    # client has applied 2 local changes
    change1 = Sync.clamp(change1, client)
    client = apply_change(client, change1)
    # assert client == "$%^&*()"
    change2 = Sync.clamp(change2, client)
    client = apply_change(client, change2)
    # assert client == "$%^&*()BBBBBBBBBBBBBB"

    # client then recieves the server change, and recognizes it was sent before its local changes were recieved.
    # client reconciles the incoming change against its unrecieved changes, and then applies it

    {_change1_p, change3_p} = Sync.reconcile(change1, change3)
    {_change2_p, change3_pp} = Sync.reconcile(change2, change3_p)

    # assert change3_pp == {:delete, 6, 2}
    client = apply_change(client, change3_pp)
    # assert client == "$%^&*()BBBBBBBBBBBBBB"

    # client then sends its changes to server, and server does the same.
    {change1_p, change3_p} = Sync.reconcile(change1, change3)
    server = apply_change(server, change1_p)
    # assert server == "#$%^&*"

    {change2_p, _change3_pp} = Sync.reconcile(change2, change3_p)
    server = apply_change(server, change2_p)
    # assert server == "#$%^&*BBBBBBBBBBBBB"

    # the client and server should now have identical documents!
    assert server == client
  end
end
