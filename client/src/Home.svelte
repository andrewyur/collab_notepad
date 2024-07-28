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

<main>
  <input type="text" bind:value={name} />
  <button on:click={createNewDoc}>Create</button>
  <p>active notes:</p>
  <div>
    {#each Object.keys(documents) as name}
      <a href={`${serverUrl}/document/${documents[name]}`}>{name}</a>
    {/each}
  </div>
</main>

<style>
  button {
    width: 100px;
    height: 50px;
  }
</style>
