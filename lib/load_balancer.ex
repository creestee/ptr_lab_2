defmodule LoadBalancer do
  use GenServer

  def init(_) do
    {:ok, nil}
  end

  def start_link(_init_args) do
    GenServer.start_link(__MODULE__, nil, name: :mediator)
  end

  def handle_cast({:mediate, message}, _state) do
    GenServer.cast(smallest_queue_pid(Enum.map(Supervisor.which_children(WorkerPool), fn {_, pid, _, _} -> pid end)), {:print, message})
    {:noreply, nil}
  end

  defp smallest_queue_pid(worker_pids) do
    worker_pids
    |> Enum.map(fn pid -> {pid, Process.info(pid, :message_queue_len)} end)
    |> Enum.min_by(fn {_, {_, queue_len}} -> queue_len end)
    |> elem(0)
  end
end
