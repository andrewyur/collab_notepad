<script lang="ts">
  import Editor from "./lib/ Editor.svelte";

  const websocketUrl = `ws://${window.location.host}${window.location.pathname}/edit`;
  let websocket = new WebSocket(websocketUrl);
  let connected = false;

  websocket.addEventListener("open", async (e) => {
    connected = true;

    websocket.addEventListener("error", (e) => {
      connected = false;
      alert("An error occured when connecting to the Server!");
    });

    websocket.addEventListener("close", (e) => {
      connected = false;
      alert(`Connection closed: ${e.reason}`);
    });
  });
</script>

<main>
  {#if connected}
    <Editor {websocket} />
  {/if}
</main>

<style>
</style>
