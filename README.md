# CollabNotepad

Server for a realtime collaborative text editor using my own Operational Transformation algorithm

Using elixir & bandit for the back end, and svelte & quill for the front end

This server is not really optimized for scale, both because it would be hard to load test, and because I don't really expect this to be used frequently. However, I did make use of OTP's fault tolerance features to make sure the server can run without supervison.

I have heard a good amount of horror stories about runaway cloud computing costs, so I did take some time to make sure that all connections have a time out, implementing rate limiting for costly services, and making sure that I used a hosting service that scales to zero.

## Technical details

The text resolution algorithm that is used to make sure changes from clients don't result in divergent end states, even in the event of slow connections, uses a technology known as [Operational Transformation](https://en.wikipedia.org/wiki/Operational_transformation). The specific algorithm I used is based off of the one described in [this paper](https://en.wikipedia.org/wiki/Operational_transformation), and is located in both the server and the client code.

The client and server(aka. document process) communicate through websocket, with an intermediate process on the server side which acts as a message translator, and handler of the websocket connection. The process ids of document processes are kept in a registry, linked to their document ids, so all a process needs to know to send a message to a document process is the document id. 

The document processes are supervised by a dynamic supervisor, which itsself is supervised by the application level supervisor, which also tracks the web server and the document process registry.

## Resources

- <https://livebook.manning.com/book/elixir-in-action-third-edition/>
- <https://samuelmullen.com/articles/elixir-processes-testing>
- <https://dl.acm.org/doi/pdf/10.1145/215585.215706>
- <https://hexdocs.pm/plds/PLDS.html>
