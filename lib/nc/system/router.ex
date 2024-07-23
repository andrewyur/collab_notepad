# this should be the entry point for clients, and should eventually transitition into the http server

defmodule Nc.System.Router do
  use Plug.Router
  use Plug.Debugger

  plug(Plug.Logger, log: :debug)

  # this will need a filter at some point before production
  plug(Plug.Static, at: "/", from: "client/dist")
  plug(:match)
  plug(:dispatch)

  get "page1" do
    conn = put_resp_content_type(conn, "text/html")
    send_file(conn, 200, "client/dist/page1.html")
  end

  get "page2" do
    conn = put_resp_content_type(conn, "text/html")
    send_file(conn, 200, "client/dist/page2.html")
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
