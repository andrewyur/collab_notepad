# CollabNotepad

Server for a realtime collaborative text editor using my own Operational Transformation algorithm

Using elixir & bandit for the back end, and svelte & quill for the front end

This server is not really optimized for scale, both because it would be hard to load test, and because I don't really expect this to be used frequently. However, I did make use of OTP's fault tolerance features to make sure the server can run without supervison.

I have heard a good amount of horror stories about runaway cloud computing costs, so I did take some time to make sure that all connections have a time out, implementing rate limiting for costly services, and making sure that I used a hosting service that scales to zero.

## Technical details

The text resolution algorithm used to make sure changes from clients don't result in divergent end states, even in the event of slow connections, uses a technology known as [Operational Transformation](https://en.wikipedia.org/wiki/Operational_transformation). The specific algorithm I used is based off of the one described in [this paper](https://en.wikipedia.org/wiki/Operational_transformation), and is located in both the server and the client code.

The client and server(aka. document process) communicate through websocket, with an intermediate process on the server side which acts as a message translator, and handler of the websocket connection. The process ids of document processes are kept in a registry, linked to their document ids, so all a process needs to know to send a message to a document process is the document id. 

The document processes are supervised by a dynamic supervisor, which itsself is supervised by the application level supervisor, which also tracks the web server and the document process registry.

## Resources

- <https://livebook.manning.com/book/elixir-in-action-third-edition/>
- <https://samuelmullen.com/articles/elixir-processes-testing>
- <https://dl.acm.org/doi/pdf/10.1145/215585.215706>
- <https://hexdocs.pm/plds/PLDS.html>

## Journal

- ~~did not want to use pheonix because the client and the server have to be separate so that the editor can still be responsive with a slow connection. From what I can tell, pheonix & liveview is geared more toward server side rendering~~ the real reason for this is because pheonix has its own version of conflict resolution for real time communication (Channels), and it seems dumb to learn how to use pheonix to make a web server and to not use that part of it. will definitely be using it in the future though
- currently not liking the lack of a type system...
- automated testing turned out to be a lot easier and a lot more useful than I thought it would be testing the processes is a lot more involved though
- god i should have just found an OT implementation online somewhere, all i wanted to do was learn how to use elixir
- OT Implemenation found! won't be completely copying this model, but adapting it to fit my current infrastructure
- Just got past the point at which i had to remake everything, looks like i will be able to pull and push separately, which is really nice
- There are a lot of moving parts and separate entities that need to be kept track of, one of the hardest things for me is finding names for everything
- I LOVE DEBUGGING TESTS !!!!!!
- setting up a web server is looking to be very tedious...
- I originally wanted to implement the text editor with html textarea and compose the changes from scratch, but it turns out textarea lacks a (widely supported) way to track the user's cursor position. The only options for me were to:
  - use textarea, but manually track keydown and click events and try to infer the cursor position based off of those (very hacky)
  - create an editor from scratch, using raw `<p>` elements to display text, and tracking events to detect changes (a lot of work)
  - use a library that has already done the above for me
- I ended up choosing the third option, and going with the Quill library. It turns out this library also has an operational transform implementation, but oh well. what can i do...
- deciding not to refactor the tests so that they work with the current implementation because:
  - I dont plan on touching the part of the code that the tests cover
  - there have been so many significant changes and it would take a lot of work
  - the lsp is not showing errors properly, and so to check where the errors are i would have to run the tests every time i change something
- just realized my use of the terms "note" and "document" to describe the place where the user writes things is horribly inconsistent (as well as my use of snake_case and CamelCase)
- getting this to run on a cloud provider is really sucking
