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

  const websocketUrl = `${import.meta.env.PROD ? "wss" : "ws"}://${window.location.host}${window.location.pathname}/edit`;
  let websocket = new WebSocket(websocketUrl);
  let connected = false;
  let failed: string | null = null;

  websocket.addEventListener("open", async (e) => {
    connected = true;
  });

  websocket.addEventListener("close", (e) => {
    connected = false;

    console.log(e);

    switch (e.code) {
      // cannot figure out why the time out is throwing error code 1002, this is a workaround
      case 1002:
        failed ||= "You have been idle too long!";
        break;
      case 1000:
        failed ||= "Document not found!";
        break;
      case 1013:
        failed ||= "You have been rate limited! Relax!";
        break;
      default:
        failed ||= "Reason unknown...";
    }
  });
</script>

<svelte:head>
  {#if editors_value > 0}
    <title>{`${title_value} | ${editors_value - 1}`}</title>
  {/if}
</svelte:head>

<nav>
  <a href={window.location.href} target="_blank">open again</a>
  <a href={window.location.origin}>main page</a>
</nav>
<main>
  {#if connected}
    <h1>{title_value}</h1>
    <p>other editors: {editors_value - 1}</p>
    <Editor {websocket} />
  {/if}

  {#if failed != null}
    <h1>Connection Closed</h1>
    <p>{failed}</p>
  {/if}
</main>

<style>
  nav {
    position: fixed;
    top: 5%;
    left: 0;
    right: 0;
  }

  h1 {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    margin-bottom: 0;
  }

  p {
    margin-top: 0;
    font-size: small;
    margin-bottom: 30px;
  }

  a {
    border-radius: 8px;
    padding: 0.6em 1.2em;
    font-size: 1em;
    font-weight: 500;
    font-family: inherit;
    cursor: pointer;
    transition: border-color 0.25s;
    text-decoration: none;
    background-color: #1a1a1a;
    color: rgba(255, 255, 255, 0.87);
  }
  a:focus,
  a:focus-visible {
    outline: 4px auto -webkit-focus-ring-color;
  }

  @media (prefers-color-scheme: light) {
    a {
      background-color: #f9f9f9;
      color: #213547;
    }
  }
</style>
