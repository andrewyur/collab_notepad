# CollabNotepad

Server for a collaborative realtime text editor using my own Operational Transformation algorithm & WebSocket

Using elixir & OTP for the back end, and svelte for the interactive front end

Did not want to use pheonix because the client and the server have to be separate so that the editor can still be responsive with a slow connection. From what I can tell, pheonix & liveview is geared more toward server side rendering 

currently not liking the lack of a type system...

automated testing turned out to be a lot easier and a lot more useful than I thought it would be
testing the processes is a lot more involved though

god i should have just found an OT implementation online somewhere, all i wanted to do was learn how to use elixir

# TODO
- integrate stateful clients + synchronizer
  - client integration tests 
- svelte front end
- process manager, supervisors
- landing page, create new doc page

# Resources
- https://www.linkedin.com/pulse/design-google-docs-crdt-operational-transformation/
- https://medium.com/coinmonks/operational-transformations-as-an-algorithm-for-automatic-conflict-resolution-3bf8920ea447
- https://livebook.manning.com/book/elixir-in-action-third-edition/
- https://samuelmullen.com/articles/elixir-processes-testing