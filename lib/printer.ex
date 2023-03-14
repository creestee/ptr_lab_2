defmodule Printer do
  use GenServer
  require Logger

  @range_multiplier 6

  def start(name) do
    GenServer.start_link(__MODULE__, name, name: name)
  end

  def init(printer_id) do
    {:ok, printer_id}
  end

  def handle_cast({:print, message}, printer_id) do
    Process.sleep(trunc(Statistics.Distributions.Poisson.rand(25)) * @range_multiplier)

    case JSON.decode(message) do
      {:ok, chunk_result} ->
        hashtags = Enum.map(chunk_result["message"]["tweet"]["entities"]["hashtags"], fn x -> Map.get(x, "text") end)
        case hashtags do
          [] ->
            nil
          _ ->
            GenServer.cast(:analyzer, {:new_hashtags, hashtags})
        end
        IO.puts("#{printer_id} -- #{chunk_result["message"]["tweet"]["text"]}")

      {:error, _} ->
        Logger.warn("#{printer_id} has crashed...")
        Process.exit(self(), :kill)
    end

    {:noreply, printer_id}
  end
end
