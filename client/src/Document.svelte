<script lang="ts">
  import WebSocketClient from "websocket-async";
  import Editor from "./lib/ Editor.svelte";

  const websocket = new WebSocketClient();
  let connected = false;

  (async () => {
    // attempt to create a new websocket with server
    const websocketUrl = `ws://${window.location.host}${window.location.pathname}/edit`;
    await websocket.connect(websocketUrl);
    connected = true;

    // if successful, pass websocket to the document editor, and display in the page
    // if not successful, display error to the user

    websocket._socket.addEventListener("error", (e) => {
      connected = false;
      alert("An Error Occured when Connecting to the Server!");
    });

    websocket._socket.addEventListener("close", (e) => {
      connected = false;
      alert(`Connection Closed: ${e.reason}`);
    });
  })();
</script>

<main>
  {#if connected}
    <Editor {websocket} />
  {/if}
</main>

<style>
</style>
