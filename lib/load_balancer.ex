defmodule LoadBalancer do
  use GenServer

  def init(_) do
    WorkerPool.start_link(3)
    {:ok, nil}
  end

  def start_link(_init_args) do
    GenServer.start_link(__MODULE__, nil, name: :mediator)
  end

  def handle_cast({:mediate, message}, _state) do
    GenServer.cast(smallest_queue_pid([:printer_1, :printer_2, :printer_3]), {:print, message})

    {:noreply, nil}
  end

  defp smallest_queue_pid(worker_pid_names) do
    worker_pid_names
    |> Enum.filter(fn name -> Process.whereis(name) != nil end)
    |> Enum.map(fn name -> {name, Process.info(Process.whereis(name), :message_queue_len)} end)
    |> Enum.min_by(fn {_, queue_len} -> queue_len end)
    |> elem(0)
  end
end
