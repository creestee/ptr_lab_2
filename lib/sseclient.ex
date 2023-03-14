defmodule SseClient do
  use GenServer
  require Logger

  def start_link([url, pid_mediator]) do
    GenServer.start_link(__MODULE__, url: url, pid_mediator: pid_mediator)
  end

  def init([url: url, pid_mediator: pid_mediator]) do
    Logger.info("Connecting to stream...")
    HTTPoison.get!(url, [], [recv_timeout: :infinity, stream_to: self()])
    {:ok, pid_mediator}
  end

  def handle_info(%HTTPoison.AsyncChunk{chunk: chunk}, pid_mediator) do
    case Regex.run(~r/data: ({.+})\n\n$/, chunk) do
      [_, data] ->
        GenServer.cast(pid_mediator, {:mediate, data})
      nil ->
        raise "Don't know how to parse received chunk: \"#{chunk}\""
    end
    {:noreply, pid_mediator}
  end

  def handle_info(%HTTPoison.AsyncStatus{} = _status, state) do
    {:noreply, state}
  end

  def handle_info(%HTTPoison.AsyncHeaders{} = _headers, state) do
    {:noreply, state}
  end
end
