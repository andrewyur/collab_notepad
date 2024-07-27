<script lang="ts">
  import WebSocketClient from "websocket-async";

  type windowState = "Connecting" | "Success" | "Failed";
  let currentState: windowState = "Connecting";

  const websocket = new WebSocketClient();

  (async () => {
    // attempt to create a new websocket with server
    const websocketUrl = `ws://${window.location.host}${window.location.pathname}/edit`;
    await websocket.connect(websocketUrl);

    // if successful, pass websocket to the document editor, and display in the page

    // if not successful, display error to the user

    websocket._socket.addEventListener("message", (e) => {
      alert(e.data);
    });

    websocket._socket.addEventListener("error", (e) => {
      currentState = "Failed";
      alert("An Error Occured when Connecting to the Server!");
    });

    websocket._socket.addEventListener("close", (e) => {
      alert(`Connection Closed: ${e.reason}`);
    });
  })();
</script>

<main>
  <button on:click={() => websocket.send("hi")}>say hi to the document</button>
</main>

<style>
</style>
