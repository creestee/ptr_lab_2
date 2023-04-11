defmodule PoolManager do
  use GenServer
  require Logger

  @delay_time 1000

  def init({min_workers_limit, max_workers_limit, average_num_tasks}) do
    {:ok, {min_workers_limit, max_workers_limit, average_num_tasks}}
  end

  def start_link({min_workers_limit, max_workers_limit, average_num_tasks}) do
    {:ok, pid} = GenServer.start_link(
      __MODULE__,
      {min_workers_limit, max_workers_limit, average_num_tasks},
      name: __MODULE__)
    Process.send_after(__MODULE__, :check, @delay_time)
    {:ok, pid}
  end

  def handle_info(:check, {min_workers_limit, max_workers_limit, average_num_tasks}) do
    current_num_tasks =
      Supervisor.which_children(WorkerPool)
      |> Enum.map(fn {_, pid, _, _} -> elem(Process.info(pid, :message_queue_len), 1) end)
      |> Enum.sum()

    current_num_children = Enum.count(Supervisor.which_children(WorkerPool))
    current_avg_tasks = current_num_tasks / current_num_children

    cond do
      current_num_children > max_workers_limit ->
        Supervisor.terminate_child(WorkerPool, current_num_children)
        Supervisor.delete_child(WorkerPool, current_num_children)

      current_num_children < min_workers_limit ->
        Supervisor.start_child(WorkerPool, %{
          id: current_num_children + 1,
          start: {Printer, :start, [:"printer_#{current_num_children + 1}"]}
        })

      current_avg_tasks > average_num_tasks && current_num_children < max_workers_limit ->
        Supervisor.start_child(WorkerPool, %{
          id: current_num_children + 1,
          start: {Printer, :start, [:"printer_#{current_num_children + 1}"]}
        })
        # Logger.info("\e[30;144;255mAdded worker:\e[0m :printer_#{current_num_children + 1}")

      current_avg_tasks < average_num_tasks && current_num_children > min_workers_limit ->
        Supervisor.terminate_child(WorkerPool, current_num_children)
        Supervisor.delete_child(WorkerPool, current_num_children)
        # Logger.info("\e[210;4;45mRemoved worker:\e[0m :printer_#{current_num_children}")

      true ->
        nil
    end

    # Logger.info %{
    #   children_alive: current_num_children,
    #   current_avg_tasks: current_avg_tasks
    # }

    Process.send_after(__MODULE__, :check, @delay_time)
    {:noreply, {min_workers_limit, max_workers_limit, average_num_tasks}}
  end
end
