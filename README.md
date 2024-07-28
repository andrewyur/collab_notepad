# CollabNotepad

Server for a collaborative realtime text editor using my own Operational Transformation algorithm & WebSocket

Using elixir & bandit for the back end, and svelte for the front end

## TODO

- figure out how to make helper functions work properly with the ls
- refactor server tests to fit project structure
  - add option to start a document with any given text
- make sure type annotations are added for everything
- fully flesh out the web client design
  - home bar
    - button to back to the home screen
    - button to copy the doument link to the clipboard
    - button to open the document in another tab
  - Editor configuration
    - padding inside editor
    - background color
    - remove spellcheck
    - line height
    - add options as a div to the side
    - pull and push buttons are greyed out when automatic synchronization is on
  - Home Page
    - add usage tips (how the conflict resolution algorithm can handle a lot)
    - link to the repository
    - link to the article in my personal portfolio
- make a ton of cool charts in the readme showing the supervision tree, process creation flow, message handling process, and my OT implementation
- error logging
- dockerize & set up CI
- buy the super-youtube.com domain
- figure out how to host on a cloud provider
- use ecto to persist documents?

## Resources

- <https://www.linkedin.com/pulse/design-google-docs-crdt-operational-transformation/>
- <https://medium.com/coinmonks/operational-transformations-as-an-algorithm-for-automatic-conflict-resolution-3bf8920ea447>
- <https://livebook.manning.com/book/elixir-in-action-third-edition/>
- <https://samuelmullen.com/articles/elixir-processes-testing>
- <https://dl.acm.org/doi/pdf/10.1145/215585.215706>

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
