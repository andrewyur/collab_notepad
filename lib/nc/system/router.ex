# this should be the entry point for clients, and should eventually transitition into the http server

defmodule Nc.System.Router do
  alias Nc.System.DocumentSupervisor

  use Plug.Router
  use Plug.Debugger

  # plug(Plug.Logger, log: :debug)

  plug(:match)

  plug(Plug.Static, at: "/", from: "client/dist")

  plug(:dispatch)

  get "/" do
    conn
    |> put_resp_content_type("text/html")
    |> send_file(200, "client/dist/home.html")
    |> halt()
  end

  get "/new" do
    case DocumentSupervisor.new_document() do
      {{:ok, _pid}, document_id} ->
        send_resp(
          conn,
          200,
          Poison.encode!(%{
            id: document_id
          })
        )

      {{:error, reason}, _document_id} ->
        send_resp(
          conn,
          500,
          Poison.encode!(%{
            "reason" => reason
          })
        )
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
    WebSockAdapter.upgrade(conn, Nc.Workers.ClientHandler, id, [])
  end

  match _ do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(404, "Not Found")
    |> halt()
  end
end
