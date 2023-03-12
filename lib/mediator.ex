defmodule Mediator do
  use GenServer

  @workers_count 3

  def init(_) do
    {:ok, 1}
  end

  def start() do
    GenServer.start_link(__MODULE__, nil)
  end

  def handle_cast({:mediate, message}, state) do
    GenServer.cast(:"printer_#{state}", {:print, message})
    if state == @workers_count, do: {:noreply, 1}, else: {:noreply, state + 1}
  end
end
