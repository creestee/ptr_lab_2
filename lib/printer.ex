defmodule Printer do
  use GenServer
  require Logger

  @range_multiplier 2

  def start(name) do
    GenServer.start_link(__MODULE__, name, name: name)
  end

  def init(printer_id) do
    {:ok, printer_id}
  end

  defp load_json(file) do
    with {:ok, body} <- File.read(file),
         {:ok, json} <- JSON.decode(body), do: json
  end

  def filter_bad_words(str, bad_words) do
    String.split(str, " ")
    |> Enum.map(fn x -> if Enum.member?(bad_words, x), do: String.duplicate("*", String.length(x)), else: x end)
    |> Enum.join(" ")
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

        json_bad_words = load_json("./lib/util/badwords.json")["en"] ++
                         load_json("./lib/util/badwords.json")["es"]

        # IO.puts("#{printer_id} -- #{filter_bad_words(chunk_result["message"]["tweet"]["text"], json_bad_words)}")

      {:error, _} ->
        Logger.warn("#{printer_id} has crashed...")
        Process.exit(self(), :kill)
    end

    {:noreply, printer_id}
  end
end
