# this should be the entry point for clients, and should eventually transitition into the http server

defmodule Nc.System.Router do
  @defaulttext "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."

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
        case DocumentSupervisor.new_document(conn.query_params["name"], @defaulttext) do
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
