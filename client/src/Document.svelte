<script lang="ts">
  type windowState = "Connecting" | "Success" | "Failed";
  let currentState: windowState = "Connecting";

  // attempt to create a new websocket with server
  const websocketUrl = `ws://${window.location.host}${window.location.pathname}/edit`;
  const websocket = new WebSocket(websocketUrl);

  // if successful, pass websocket to the document editor, and display in the page

  // if not successful, display error to the user

  websocket.addEventListener("message", (e) => {
    alert(e.data);
  });

  websocket.addEventListener("error", (e) => {
    currentState = "Failed";
    alert("An Error Occured when Connecting to the Server!");
  });

  websocket.addEventListener("close", (e) => {
    alert(`Connection Closed: ${e.reason}`);
  });
</script>

<main>
  <button on:click={() => websocket.send("hi")}>say hi to the document</button>
</main>

<style>
</style>
