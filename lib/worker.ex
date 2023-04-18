defmodule Worker do
  use GenServer
  require Logger

  @range_multiplier 2

  def start(name) do
    GenServer.start_link(__MODULE__, name, name: name)
  end

  def init(worker_id) do
    {:ok, worker_id}
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

  def handle_cast({:print, message}, worker_id) do
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

        text = filter_bad_words(chunk_result["message"]["tweet"]["text"], load_json("./lib/util/badwords.json")["en"])

        GenServer.cast(:batcher, {:collect, text})

        words = String.split(text)
        sentiment_scores_sum =
          words |> Enum.reduce(0, fn word, acc ->
            acc + Map.get(emotional_score_map(), word, 0)
          end)

        sentiment_score = sentiment_scores_sum / length(words)

        favorite_count = chunk_result["message"]["tweet"]["retweeted_status"]["favorite_count"] || 0
        retweet_count = chunk_result["message"]["tweet"]["retweeted_status"]["retweet_count"] || 0
        followers_count = chunk_result["message"]["tweet"]["user"]["followers_count"]

        engagement_score =
          cond do
            followers_count == 0 ->
              0
            followers_count != 0 ->
              (favorite_count + retweet_count) / followers_count
          end

        # %{
        #   :sentiment_score => sentiment_score,
        #   :engagement_score => engagement_score,
        #   :tweet_text => text
        # }
        # |> IO.inspect

      {:error, _} ->
        # Logger.warn("#{printer_id} has crashed...")
        Process.exit(self(), :kill)
    end

    {:noreply, worker_id}
  end

  defp emotional_score_map() do
    %{body: response} = HTTPoison.get!("http://localhost:4000/emotion_values")

    response
      |> String.split("\r\n")
      |> Enum.map(fn string ->
        [key, value] = String.split(string, "\t")
        {key, String.to_integer(value)}
      end)
      |> Enum.into(%{})
  end
end
