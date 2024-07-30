# this should be the entry point for clients, and should eventually transitition into the http server

defmodule Nc.System.Router do
  @defaulttext [
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
    "A beginning is the time for taking the most delicate care that the balances are correct. This every sister of the Bene Gesserit knows. To begin your study of the life of Muad'Dib, then, take care that you first place him in his time: born in the 57th year of the Padishah Emperor, Shaddam IV. And take the most special care that you locate Muad'Dib in his place: the planet Arrakis. Do not be deceived by the fact that he was born on Caladan and lived his first fifteen years there. Arrakis, the planet known as Dune, is forever his place.",
    "Maman died today. Or yesterday maybe, I don't know. I got a telegram from the home: \"Mother deceased. Funeral tomorrow. Faithfully yours.\" That doesn't mean anything. Maybe it was yesterday.",
    "In the shade of the house, in the sunshine of the riverbank near the boats, in the shade of the Sal-wood forest, in the shade of the fig tree is where Siddhartha grew up, the handsome son of the Brahman, the young falcon, together with his friend Govinda, son of a Brahman. The sun tanned his light shoulders by the banks of the river when bathing, performing the sacred ablutions, the sacred offerings. In the mango grove, shade poured into his black eyes, when playing as a boy, when his mother sang, when the sacred offerings were made, when his father, the scholar, taught him, when the wise men talked.",
    "Git is a free and open source distributed version control system designed to handle everything from small to very large projects with speed and efficiency.\nGit is easy to learn and has a tiny footprint with lightning fast performance. It outclasses SCM tools like Subversion, CVS, Perforce, and ClearCase with features like cheap local branching, convenient staging areas, and multiple workflows.",
    "Elixir is a dynamic, functional language for building scalable and maintainable applications.\nElixir runs on the Erlang VM, known for creating low-latency, distributed, and fault-tolerant systems. These capabilities and Elixir tooling allow developers to be productive in several domains, such as web development, embedded software, machine learning, data pipelines, and multimedia processing, across a wide range of industries.",
    "What is Svelte?\nSvelte is a new way to build web applications. It's a compiler that takes your declarative components and converts them into efficient JavaScript that surgically updates the DOM."
  ]

  alias Nc.System.DocumentSupervisor

  use Plug.Router
  use Plug.Debugger

  plug(Plug.Logger, log: :debug)

  plug(:match)

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Poison
  )

  plug(Plug.Static, at: "/", from: "client/dist")

  plug(:dispatch)

  get "/" do
    conn
    |> put_resp_content_type("text/html")
    |> send_file(200, "client/dist/home.html")
    |> halt()
  end

  # this obviously would not be good at larger scales, but for right now, it is ok
  get "/names" do
    response =
      Registry.select(Nc.System.DocumentRegistry, [{{:"$1", :_, :"$3"}, [], [{{:"$3", :"$1"}}]}])
      |> Enum.into(%{})
      |> Poison.encode!()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, response)
    |> halt()
  end

  get "/new" do
    send_error = fn bad_conn, reason ->
      send_resp(
        bad_conn,
        500,
        Poison.encode!(%{
          "reason" => reason
        })
      )
    end

    conn = put_resp_content_type(conn, "application/json")

    conn =
      if !Map.has_key?(conn.query_params, "name") do
        send_error.(conn, "Document must have a name!")
      else
        case DocumentSupervisor.new_document(conn.query_params["name"], Enum.random(@defaulttext)) do
          {{:ok, _pid}, document_id} ->
            send_resp(
              conn,
              200,
              Poison.encode!(%{
                id: document_id
              })
            )

          {{:error, reason}, _document_id} ->
            send_error.(conn, reason)
        end
      end

    halt(conn)
  end

  get "/document/:id" do
    conn
    |> put_resp_content_type("text/html")
    |> send_file(200, "client/dist/document.html")
    |> halt()
  end

  get "/document/:id/edit" do
    conn
    |> WebSockAdapter.upgrade(Nc.Workers.ClientHandler, id, timeout: 6_000_000)
    |> halt()
  end

  match _ do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(404, "Not Found")
    |> halt()
  end
end
