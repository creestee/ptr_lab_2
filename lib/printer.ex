defmodule Printer do
  use GenServer

  def start(name) do
    GenServer.start_link(__MODULE__, nil, name: name)
  end

  def init(_) do
    {:ok, nil}
  end

  def handle_cast({:print, message}, _) do
    Process.sleep(Enum.random(500..2000))
    IO.inspect "#{inspect self()} -- #{message}"
    {:noreply, nil}
  end
end
