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
  let idle = false;

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

  let push = async () => false;

  let pull = async () => false;

  onMount(async () => {
    const quill = new Quill("#editor", {
      modules: {
        toolbar: false,
      },
      theme: "bubble",
      formats: [],
      placeholder: "Type Here!",
    });

    quill.setText(await messenger.init());

    quill.on("text-change", (changeDelta, mergedDelta, source) => {
      if (source == "user") {
        uncondensed = uncondensed.compose(changeDelta);
      }
    });

    const condense_changes = () => {
      const changes_uncondensed = delta_to_changes(uncondensed);
      unpushed += changes_uncondensed.length;
      pending = [...pending, ...changes_uncondensed];
      uncondensed = new Delta();
    };

    setInterval(
      () => {
        if (idle) {
          // this tomfoolery has to happen because providing a code to .close() does not set the close code for the CloseEvent...

          messenger._reciever._websocket.dispatchEvent(
            new CloseEvent("close", { code: 1002 })
          );

          messenger._reciever._websocket.close();
        } else {
          idle = true;
        }
      },
      1000 * 60 * 5
    );

    push = async (): Promise<boolean> => {
      condense_changes();

      if (unpushed > 0) {
        messenger.sendPush(pending.slice(-1 * unpushed, pending.length + 1));
        unpushed = 0;
        return false;
      }
      return true;
    };

    pull = async (): Promise<boolean> => {
      const newChanges = await messenger.sendPull();

      condense_changes();

      const changeObj = reconcileAgainst(newChanges, pending);
      const changes_to_apply = changeObj.new_incoming_list;
      pending = changeObj.new_outgoing_list;

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

      return newChanges.length == 0;
    };
  });

  const handleCheckbox = (e: MouseEvent) => {
    if ((e.target as HTMLInputElement).checked) {
      autoSyncHandle = setInterval(async () => {
        idle = idle && (await pull());
        idle = idle && (await push());
      }, 500);
    } else {
      if (autoSyncHandle) {
        clearInterval(autoSyncHandle);
        autoSyncHandle = null;
      }
    }
  };
</script>

<div id="editor"></div>
<button on:click={pull} disabled={autoSyncHandle != null}>pull</button>
<button on:click={push} disabled={autoSyncHandle != null}>push</button>
<label>
  <input type="checkbox" on:click={handleCheckbox} />
  automatic
</label>
