defmodule Mediator do
  use GenServer
  require Logger

  @workers_count 3

  def init(_) do
    WorkerPool.start_link(3)
    {:ok, 1}
  end

  def start_link(_init_args) do
    GenServer.start_link(__MODULE__, nil, name: :mediator)
  end

  def handle_cast({:mediate, message}, state) do
    GenServer.cast(:"printer_#{state}", {:print, message})
    if state == @workers_count, do: {:noreply, 1}, else: {:noreply, state + 1}
  end

  def handle_cast(:crash, state) do
    Logger.warn("Printer_#{state} has crashed...")
    GenServer.cast(:"printer_#{state}", :crash)
    if state == @workers_count, do: {:noreply, 1}, else: {:noreply, state + 1}
  end
end
