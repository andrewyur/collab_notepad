<script lang="ts">
  import WebSocketClient from "websocket-async";
  import Editor from "./lib/ Editor.svelte";

  type windowState = "Connecting" | "Success" | "Failed";
  let currentState: windowState = "Connecting";

  const websocket = new WebSocketClient();

  (async () => {
    // attempt to create a new websocket with server
    const websocketUrl = `ws://${window.location.host}${window.location.pathname}/edit`;
    await websocket.connect(websocketUrl);
    currentState = "Success";

    // if successful, pass websocket to the document editor, and display in the page

    // if not successful, display error to the user

    websocket._socket.addEventListener("error", (e) => {
      currentState = "Failed";
      alert("An Error Occured when Connecting to the Server!");
    });

    websocket._socket.addEventListener("close", (e) => {
      alert(`Connection Closed: ${e.reason}`);
      currentState = "Failed";
    });
  })();
</script>

<main>
  {#if currentState == "Success"}
    <Editor {websocket} />
  {/if}
</main>

<style>
</style>
