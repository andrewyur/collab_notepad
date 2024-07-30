<script lang="ts">
  import Editor from "./lib/ Editor.svelte";
  import { editors, title } from "./stores";

  let title_value: string;
  title.subscribe((value) => {
    title_value = value;
  });

  let editors_value: number;
  editors.subscribe((value) => {
    editors_value = value;
  });

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

  const copyLink = () => {
    navigator.clipboard.writeText(window.location.href);
  };

  const goBack = () => {
    window.location.href = import.meta.env.VITE_SERVER_URL;
  };
</script>

<svelte:head>
  <title
    >{editors_value > 0
      ? `${title_value} | ${editors_value - 1}`
      : "not found"}</title
  >
</svelte:head>

<nav>
  <button on:click={copyLink}>copy link</button>
  <button on:click={goBack}>main page</button>
</nav>
<main>
  {#if connected}
    <h1>{title_value}</h1>
    <p>other editors: {editors_value - 1}</p>
    <Editor {websocket} />
  {/if}
</main>

<style>
</style>
