defmodule SseClient do
  use GenServer

  def start(url) do
    WorkerPool.start_link(3)
    {:ok, pid_mediator} = Mediator.start()
    {:ok, pid_analyzer} = AnalyzeTweets.start()
    GenServer.start_link(__MODULE__, url: url, pid_mediator: pid_mediator, pid_analyzer: pid_analyzer)
  end

  def init([url: url, pid_mediator: pid_mediator, pid_analyzer: pid_analyzer]) do
    IO.puts "Connecting to stream..."
    HTTPoison.get!(url, [], [recv_timeout: :infinity, stream_to: self()])
    {:ok, {pid_mediator, pid_analyzer}}
  end

  def handle_info(%HTTPoison.AsyncChunk{chunk: chunk}, {pid_mediator, pid_analyzer}) do
    case Regex.run(~r/data: ({.+})\n\n$/, chunk) do
      [_, data] ->
        with {:ok, chunk_result} <- JSON.decode(data) do
          hashtags = Enum.map(chunk_result["message"]["tweet"]["entities"]["hashtags"], fn x -> Map.get(x, "text") end)
          case hashtags do
            [] ->
              nil
            _ ->
              GenServer.cast(pid_analyzer, {:new_hashtags, hashtags})
          end
          GenServer.cast(pid_mediator, {:mediate, chunk_result["message"]["tweet"]["text"]})
        end
      nil ->
        raise "Don't know how to parse received chunk: \"#{chunk}\""
    end
    {:noreply, {pid_mediator, pid_analyzer}}
  end

  def handle_info(%HTTPoison.AsyncStatus{} = _status, state) do
    # IO.puts "Connection status: #{inspect status}"
    {:noreply, state}
  end

  def handle_info(%HTTPoison.AsyncHeaders{} = _headers, state) do
    # IO.puts "Connection headers: #{inspect headers}"
    {:noreply, state}
  end
end
