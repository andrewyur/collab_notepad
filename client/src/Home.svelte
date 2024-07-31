<script lang="ts">
  import { onMount } from "svelte";

  let name = "Untitled Note";
  let documents: { [key: string]: string } = {};

  const serverUrl = import.meta.env.VITE_SERVER_URL;

  let createNewDoc = async () => {
    try {
      // send request to server to make a new document
      const querystring = new URLSearchParams({ name }).toString();
      const response = await fetch(`${serverUrl}/new?${querystring}`);
      if (!response.ok) {
        throw new Error(`Response status: ${response.status}`);
      }

      // server responds with the id of the document
      const documentId = (await response.json()).id;

      // redirect user to the url of the document
      window.location.href = `${serverUrl}/document/${documentId}`;
    } catch (error) {
      if (error instanceof Error) {
        alert(`Could not create a document: (${error.message})`);
      }
    }
  };

  onMount(async () => {
    const response = await fetch(`${serverUrl}/names`);
    if (response.ok) {
      documents = await response.json();
    }
  });
</script>

<svelte:head>
  <title>Home</title>
</svelte:head>

<main>
  <h1>notepad_collab</h1>
  <div class="card">
    <input type="text" bind:value={name} />
    <button on:click={createNewDoc}>create</button>
  </div>

  {#if Object.keys(documents).length > 0}
    <p>active notes:</p>
    <div>
      {#each Object.keys(documents) as name}
        <a href={`${serverUrl}/document/${documents[name]}`}>{name}</a>
      {/each}
    </div>
  {/if}

  <p>
    This is an online demo for a text conflict resolution algorithm (Operational
    Transformation) I implemented. It can handle multiple clients, and pushing
    from a detached state (Git can't do that!), so create a note, open it in
    multiple tabs and do your best to mess it up.
  </p>
  <p>
    You can read more about the OT implementation or how I made the
    server/client in the <a href="https://github.com/andrewyur/collab_notepad"
      >repo</a
    > readme
  </p>
  <p>
    If you find a way to break the algorithm (or the server), or have any
    suggestions, please <a
      href="mailto:andy@yurovchak.net?subject=I LOVED your notepad collab app!"
      >email me</a
    >!
  </p>
</main>
