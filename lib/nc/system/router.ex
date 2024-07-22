# this should be the entry point for clients, and should eventually transitition into the http server

defmodule Nc.System.Router do
  use Plug.Router
  use Plug.Debugger

  plug(Plug.Logger, log: :debug)

  plug(Plug.Static, at: "/", from: "client/dist")
  plug(:match)
  plug(:dispatch)

  get "/hello" do
    send_resp(conn, 200, "HI")
  end

  get "/hi" do
    send_resp(conn, 200, "HELLO")
  end

  get "/test" do
    conn = put_resp_content_type(conn, "text/html")
    send_file(conn, 200, "client/dist/index.html")
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
