<script lang="ts">
  let createNewDoc = async () => {
    const serverUrl = import.meta.env.VITE_SERVER_URL;
    try {
      // send request to server to make a new document
      const response = await fetch(`${serverUrl}/new`);
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
</script>

<main>
  <button on:click={createNewDoc}>+</button>
</main>

<style>
  button {
    width: 100px;
    height: 50px;
  }
</style>
