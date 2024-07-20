# CollabNotepad

Server for a collaborative realtime text editor using my own Operational Transformation algorithm & WebSocket

Using elixir & OTP for the back end, and svelte for the interactive front end

Did not want to use pheonix because the client and the server have to be separate so that the editor can still be responsive with a slow connection. From what I can tell, pheonix & liveview is geared more toward server side rendering

currently not liking the lack of a type system...

automated testing turned out to be a lot easier and a lot more useful than I thought it would be
testing the processes is a lot more involved though

god i should have just found an OT implementation online somewhere, all i wanted to do was learn how to use elixir

OT Implemenation found! won't be completely copying this model, but adapting it to fit my current infrastructure

Just got past the point at which i had to remake everything, looks like i will be able to pull and push separately, which is really nice

There are a lot of moving parts and separate entities that need to be kept track of, one of the hardest things for me is finding names for everything

I LOVE DEBUGGING TESTS !!!!!!

## TODO

- move client processes outside of the server architecture
  - this entails setting up stateful client proxy processes to handle interactions with the document server
  - clients should be reffered to by a UUID and not a pid
  - client should communicate with the server as a whole and not with individual document processes
- refactor tests to fit project structure (and figure out how to make helper functions work properly with the ls)
- set up webserver, transition client process into a web client
  - web client should be written in svelte
  - communication may have to be through websocket from the start (can web browsers recieve http requests?)
- use ecto to store data?

## Resources

- <https://www.linkedin.com/pulse/design-google-docs-crdt-operational-transformation/>
- <https://medium.com/coinmonks/operational-transformations-as-an-algorithm-for-automatic-conflict-resolution-3bf8920ea447>
- <https://livebook.manning.com/book/elixir-in-action-third-edition/>
- <https://samuelmullen.com/articles/elixir-processes-testing>
- <https://dl.acm.org/doi/pdf/10.1145/215585.215706>
