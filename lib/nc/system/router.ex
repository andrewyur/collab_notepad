# this should be the entry point for clients, and should eventually transitition into the http server

defmodule Nc.System.Router do
  @moduledoc """
  Plug router for http requests
  """

  @defaulttext [
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
    "A beginning is the time for taking the most delicate care that the balances are correct. This every sister of the Bene Gesserit knows. To begin your study of the life of Muad'Dib, then, take care that you first place him in his time: born in the 57th year of the Padishah Emperor, Shaddam IV. And take the most special care that you locate Muad'Dib in his place: the planet Arrakis. Do not be deceived by the fact that he was born on Caladan and lived his first fifteen years there. Arrakis, the planet known as Dune, is forever his place.",
    "Maman died today. Or yesterday maybe, I don't know. I got a telegram from the home: \"Mother deceased. Funeral tomorrow. Faithfully yours.\" That doesn't mean anything. Maybe it was yesterday.",
    "In the shade of the house, in the sunshine of the riverbank near the boats, in the shade of the Sal-wood forest, in the shade of the fig tree is where Siddhartha grew up, the handsome son of the Brahman, the young falcon, together with his friend Govinda, son of a Brahman. The sun tanned his light shoulders by the banks of the river when bathing, performing the sacred ablutions, the sacred offerings. In the mango grove, shade poured into his black eyes, when playing as a boy, when his mother sang, when the sacred offerings were made, when his father, the scholar, taught him, when the wise men talked.",
    "Git is a free and open source distributed version control system designed to handle everything from small to very large projects with speed and efficiency.\nGit is easy to learn and has a tiny footprint with lightning fast performance. It outclasses SCM tools like Subversion, CVS, Perforce, and ClearCase with features like cheap local branching, convenient staging areas, and multiple workflows.",
    "Elixir is a dynamic, functional language for building scalable and maintainable applications.\nElixir runs on the Erlang VM, known for creating low-latency, distributed, and fault-tolerant systems. These capabilities and Elixir tooling allow developers to be productive in several domains, such as web development, embedded software, machine learning, data pipelines, and multimedia processing, across a wide range of industries."
  ]

  alias Nc.System.DocumentSupervisor

  use Plug.Router
  use Plug.Debugger

  plug(RemoteIp)

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

  # this obviously would not be good at larger scales, but for right now, it is ok because this is really the only way to do this apparently
  get "/names" do
    response =
      Registry.select(Nc.System.DocumentRegistry, [{{:"$1", :_, :"$3"}, [], [{{:"$3", :"$1"}}]}])
      |> Enum.take(3)
      |> Enum.into(%{})
      |> Poison.encode!()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, response)
    |> halt()
  end

  get "/new" do
    conn = put_resp_content_type(conn, "application/json")

    conn =
      with {:ok, conn} <-
             check_rate(conn, Hammer.check_rate("new:#{inspect(conn.remote_ip)}", 500, 1)),
           {:ok, name} <- get_name(conn),
           {:ok, document_id} <- get_document(conn, name) do
        send_resp(
          conn,
          200,
          Poison.encode!(%{
            id: document_id
          })
        )
      end

    halt(conn)
  end

  defp check_rate(conn, hammer_resp) do
    case hammer_resp do
      {:allow, _} ->
        {:ok, conn}

      {:deny, _} ->
        send_resp(
          conn,
          429,
          Poison.encode!(%{
            "reason" => "Relax man!"
          })
        )
    end
  end

  defp get_name(conn) do
    case Map.fetch(conn.query_params, "name") do
      {:ok, name} ->
        {:ok, name}

      :error ->
        send_resp(
          conn,
          400,
          Poison.encode!(%{
            "reason" => "no name was provided"
          })
        )
    end
  end

  defp get_document(conn, name) do
    case DocumentSupervisor.new_document(name, Enum.random(@defaulttext)) do
      {{:ok, _pid}, document_id} ->
        {:ok, document_id}

      {{:error, reason}, _document_id} ->
        send_resp(
          conn,
          500,
          Poison.encode!(%{
            "reason" => reason
          })
        )
    end
  end

  get "/document/:id" do
    conn
    |> put_resp_content_type("text/html")
    |> send_file(200, "client/dist/document.html")
    |> halt()
  end

  # this needs to be rate limited
  get "/document/:id/edit" do
    conn =
      with {:ok, conn} <-
             check_rate(conn, Hammer.check_rate("edit:#{inspect(conn.remote_ip)}", 500, 1)) do
        WebSockAdapter.upgrade(conn, Nc.Workers.ClientHandler, {id, inspect(conn.remote_ip)},
          timeout: 10 * 60 * 1000
        )
      end

    halt(conn)
  end

  # this should redirect to / but there is no easy way to do this with plug...
  match _ do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(404, "Not Found")
    |> halt()
  end
end
