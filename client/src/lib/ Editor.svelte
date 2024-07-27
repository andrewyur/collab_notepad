<script lang="ts">
  import { Messager } from "./messager";

  export let websocket;

  const messager = new Messager(websocket);

  // apply changes

  // event listeners for textarea actions, compose changes
</script>

<textarea></textarea>
<button>Pull</button>
<button>Push</button>
<!-- <checkbox>Auto</checkbox> -->
