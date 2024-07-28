import type { Change, Insert, Delete } from "./messenger";

// this is translated directly from my implementation in elixir

function reconcile(
  change1: Change,
  change2: Change
): { change1: Change; change2: Change } {
  if (!change1 || !change2) {
    return {
      change1,
      change2,
    };
  } else {
    if (change1.type == "insert" && change2.type == "insert") {
      change1 = change1 as Insert;
      change2 = change2 as Insert;
      return insert_insert(change1, change2);
    } else if (change1.type == "insert" && change2.type == "delete") {
      change1 = change1 as Insert;
      change2 = change2 as Delete;
      return insert_delete(change1, change2);
    } else if (change1.type == "delete" && change2.type == "insert") {
      change1 = change1 as Delete;
      change2 = change2 as Insert;
      let rec = insert_delete(change2, change1);
      return {
        change1: rec.change2,
        change2: rec.change1,
      };
    } else {
      change1 = change1 as Delete;
      change2 = change2 as Delete;
      return delete_delete(change1, change2);
    }
  }
}

function insert_insert(
  change1: Insert,
  change2: Insert
): { change1: Change; change2: Change } {
  if (
    change1.position > change2.position ||
    (change1.position == change2.position && change1.text > change2.text) ||
    (change1.position == change2.position &&
      change1.text == change2.text &&
      change1.from > change2.from)
  ) {
    return {
      change1: {
        ...change1,
        position: change1.position + change2.text.length,
      },
      change2,
    };
  } else if (
    change1.position < change2.position ||
    (change1.position == change2.position && change1.text < change2.text) ||
    (change1.position == change2.position &&
      change1.text == change2.text &&
      change1.from < change2.from)
  ) {
    return {
      change1,
      change2: {
        ...change2,
        position: change2.position + change1.text.length,
      },
    };
  } else {
    return { change1: undefined, change2: undefined };
  }
}

function insert_delete(
  change1: Insert,
  change2: Delete
): { change1: Change; change2: Change } {
  if (change1.position > change2.position) {
    if (change1.position >= change2.position + change2.amount) {
      return {
        change1: {
          ...change1,
          position: change1.position - change2.amount,
        },
        change2,
      };
    } else {
      return {
        change1: undefined,
        change2: {
          ...change2,
          amount: change2.amount + change1.text.length,
        },
      };
    }
  } else {
    return {
      change1,
      change2: {
        ...change2,
        position: change2.position + change1.text.length,
      },
    };
  }
}

function delete_delete(
  change1: Delete,
  change2: Delete
): { change1: Change; change2: Change } {
  const left_1 = change1.position;
  const right_1 = change1.position + change1.amount;
  const left_2 = change2.position;
  const right_2 = change2.position + change2.amount;

  const overlap_start = Math.max(left_1, left_2);
  const overlap_end = Math.min(right_1, right_2);
  const overlap_area = overlap_end - overlap_start;

  if (overlap_area <= 0) {
    if (change1.position > change2.position) {
      return {
        change1: {
          ...change1,
          position: change1.position - change2.amount,
        },
        change2,
      };
    } else {
      return {
        change1,
        change2: {
          ...change2,
          position: change2.position - change1.amount,
        },
      };
    }
  } else if (left_1 <= left_2 && right_1 >= right_2) {
    return {
      change1: {
        ...change1,
        amount: change1.amount - change2.amount,
      },
      change2: undefined,
    };
  } else if (left_1 >= left_2 && right_1 <= right_2) {
    return {
      change1: undefined,
      change2: {
        ...change2,
        amount: change2.amount - change1.amount,
      },
    };
  } else {
    return {
      change1: {
        ...change1,
        position: Math.min(change2.position, change1.position),
        amount: change1.amount - overlap_area,
      },
      change2: {
        ...change2,
        position: Math.min(change2.position, change1.position),
        amount: change2.amount - overlap_area,
      },
    };
  }
}

// why doesnt javascript have tuples???
export function reconcileAgainst(
  incoming_list: Change[],
  outgoing_list: Change[]
): { new_incoming_list: Change[]; new_outgoing_list: Change[] } {
  const { new_incoming_list, new_outgoing_list } = incoming_list.reduce(
    reconcile_all_changes,
    { new_incoming_list: [], new_outgoing_list: outgoing_list }
  );

  return { new_incoming_list: new_incoming_list.reverse(), new_outgoing_list };
}

function reconcile_all_changes(
  changeObj: {
    new_incoming_list: Change[];
    new_outgoing_list: Change[];
  },
  incoming_change: Change
): {
  new_incoming_list: Change[];
  new_outgoing_list: Change[];
} {
  const new_incoming_list = changeObj.new_incoming_list;
  const current_outgoing_list = changeObj.new_outgoing_list;

  let { new_incoming_change, new_outgoing_list } = current_outgoing_list.reduce(
    reconcile_single_change,
    {
      new_incoming_change: incoming_change,
      new_outgoing_list: [],
    }
  );

  new_outgoing_list = new_outgoing_list.reverse();

  return {
    new_incoming_list: [new_incoming_change, ...new_incoming_list],
    new_outgoing_list: new_outgoing_list,
  };
}

function reconcile_single_change(
  changeObj: {
    new_incoming_change: Change;
    new_outgoing_list: Change[];
  },
  outgoing_change: Change
): {
  new_incoming_change: Change;
  new_outgoing_list: Change[];
} {
  const incoming_change = changeObj.new_incoming_change;
  const new_outgoing_list = changeObj.new_outgoing_list;

  const changeObj2 = reconcile(outgoing_change, incoming_change);

  const new_outgoing_change = changeObj2.change1;
  const new_incoming_change = changeObj2.change2;

  return {
    new_incoming_change,
    new_outgoing_list: [new_outgoing_change, ...new_outgoing_list],
  };
}
