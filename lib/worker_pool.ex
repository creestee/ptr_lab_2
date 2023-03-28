defmodule WorkerPool do
  use Supervisor

  def start_link(workers_count) do
    Supervisor.start_link(__MODULE__, workers_count, name: __MODULE__)
  end

  def init(workers_count) do
    children = Enum.map(1..workers_count, fn x ->
          %{id: x, start: {Printer, :start, [:"printer_#{x}"] } } end)
    Supervisor.init(children, strategy: :one_for_one)
  end

end
