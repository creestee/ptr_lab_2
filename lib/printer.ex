defmodule Printer do
  use GenServer

  def start(name) do
    GenServer.start_link(__MODULE__, nil, name: name)
  end

  def init(_) do
    {:ok, nil}
  end

  def handle_cast({:print, message}, _) do
    Process.sleep(Enum.random(500..1200))
    IO.inspect "#{inspect self()} -- #{message}"
    {:noreply, nil}
  end

  def handle_cast(:crash, _) do
    Process.exit(self(), :kill)
    {:noreply, nil}
  end
end
