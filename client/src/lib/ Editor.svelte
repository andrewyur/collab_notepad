<script lang="ts">
  import { Messenger } from "./messenger";
  import type { Change, Insert, Delete } from "./messenger";
  import Quill from "quill";
  import { Delta } from "quill/core";
  import { onMount } from "svelte";
  import { reconcileAgainst } from "./sync";

  // excuse the mixing of camel case and snake case...

  export let websocket;
  const messenger = new Messenger(websocket);

  let pending: Change[] = [];
  let unpushed = 0;
  let uncondensed = new Delta();

  let autoSyncHandle: ReturnType<typeof setInterval> | null = null;

  const delta_to_changes = (delta: Delta): Array<Change> => {
    // quill has a lot of capabilities, all we want is the ability to edit plain text and track the cursor...

    let changes: Array<Change> = [];

    let pos = 0;
    delta.ops.forEach((op) => {
      if ("retain" in op) {
        pos += op.retain as number;
      }
      if ("insert" in op) {
        changes = [
          ...changes,
          {
            type: "insert",
            position: pos,
            text: op.insert as string,
            from: messenger.clientId,
          },
        ];
        pos += (op.insert as string).length;
      }
      if ("delete" in op) {
        changes = [
          ...changes,
          {
            type: "delete",
            position: pos,
            amount: op.delete as number,
            from: messenger.clientId,
          },
        ];
      }
    });

    return changes;
  };

  let push = () => {};

  let pull = () => {};

  onMount(async () => {
    const quill = new Quill("#editor", {
      modules: {
        toolbar: false,
      },
      theme: "snow",
      formats: [],
    });

    quill.setText(await messenger.init());

    quill.on("text-change", (changeDelta, mergedDelta, source) => {
      if (source == "user") {
        uncondensed = uncondensed.compose(changeDelta);
      }
    });

    const condense_changes = () => {
      // console.log("uncondensed: ", uncondensed);

      const changes_uncondensed = delta_to_changes(uncondensed);
      unpushed += changes_uncondensed.length;
      pending = [...pending, ...changes_uncondensed];
      uncondensed = new Delta();

      // console.log("uncondensed changes: ", changes_uncondensed);
      // console.log("pending: ", pending);
    };

    push = async () => {
      condense_changes();

      // console.log(
      //   "unpushed: ",
      //   pending.slice(-1 * unpushed, pending.length + 1)
      // );

      await messenger.sendPush(
        pending.slice(-1 * unpushed, pending.length + 1)
      );
      unpushed = 0;
    };

    pull = async () => {
      const newChanges = await messenger.sendPull();

      condense_changes();

      const changeObj = reconcileAgainst(newChanges, pending);
      const changes_to_apply = changeObj.new_incoming_list;
      pending = changeObj.new_outgoing_list;

      // console.log(changeObj);

      changes_to_apply.forEach((change) => {
        switch (change?.type) {
          case undefined:
            break;
          case "delete":
            change = change as Delete;
            quill.deleteText(change.position, change.amount);
            break;
          case "insert":
            change = change as Insert;
            quill.insertText(change.position, change.text);
            break;
        }
      });
    };
  });

  const handleCheckbox = (e: MouseEvent) => {
    if ((e.target as HTMLInputElement).checked) {
      autoSyncHandle = setInterval(async () => {
        await pull();
        await push();
      }, 500);
    } else {
      if (autoSyncHandle) clearInterval(autoSyncHandle);
    }
  };
</script>

<div id="editor"></div>
<button on:click={pull}>Pull</button>
<button on:click={push}>Push</button>
<label>
  Automatic Synchronization
  <input type="checkbox" on:click={handleCheckbox} />
</label>
