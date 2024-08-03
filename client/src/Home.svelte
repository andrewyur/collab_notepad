<script lang="ts">
  import { onMount } from "svelte";

  let name = "";
  let documents: { [key: string]: string } = {};

  let createNewDoc = async () => {
    // ideally we would perform some sort of input sanitization/validation here
    if (name.length == 0) {
      alert("Note name cannot be empty!");
      return;
    }

    // send request to server to make a new document
    const querystring = new URLSearchParams({ name }).toString();
    const response = await fetch(
      `${window.location.origin}/new?${querystring}`
    );

    if (!response.ok) {
      alert("Sorry! there was an error creating a document");
    }

    // server responds with the id of the document
    const documentId = (await response.json()).id;

    // redirect user to the url of the document
    window.location.href = `${window.location.origin}/document/${documentId}`;
  };

  onMount(async () => {
    const response = await fetch(`${window.location.origin}/names`);
    if (response.ok) {
      documents = await response.json();
    }
  });
</script>

<svelte:head>
  <title>Home</title>
</svelte:head>

<main>
  <h1>collab_notepad</h1>
  <div class="card">
    <input
      type="text"
      bind:value={name}
      placeholder="type a name for the note!"
    />
    <button on:click={createNewDoc}>create</button>
  </div>

  {#if Object.keys(documents).length > 0}
    <p id="links-header">active notes:</p>
    <div id="links">
      {#each Object.keys(documents) as name}
        <a href={`${window.location.origin}/document/${documents[name]}`}
          >{name}</a
        >
      {/each}
    </div>
  {/if}

  <p>
    This is an online demo for my text conflict resolution algorithm, which uses<a
      href="https://en.wikipedia.org/wiki/Operational_transformation"
      >Operational Transformation</a
    >. It can handle multiple clients and pushing from a detached state (Git
    can't do that!), so create a note, open it in multiple tabs and do your best
    to mess it up.
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

<style>
  #links-header {
    margin: 0;
  }

  #links {
    overflow-x: hidden;
    display: flex;
    flex-direction: column;
  }
  #links * {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  input {
    margin-bottom: 5px;
  }
</style>
