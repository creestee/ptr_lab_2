defmodule AnalyzeTweets do
  use GenServer
  require Logger

  def start(name) do
    GenServer.start_link(__MODULE__, [], name: name)
  end

  def init(_state) do
    Process.send_after(self(), :print_popular_hashtag, 5_000)
    {:ok, %{hashtags: [], popular_hashtag: nil}}
  end

  def handle_info(:print_popular_hashtag, state) do
    Logger.info("\e[38;5;208mThe most popular hashtag in the last 5 seconds is:\e[0m #{state.popular_hashtag}")
    Process.send_after(self(), :print_popular_hashtag, 5_000)
    {:noreply, %{hashtags: [], popular_hashtag: nil}}
  end

  def handle_cast({:new_hashtags, hashtags}, state) do
    hashtags_list = state.hashtags ++ hashtags
    popular_hashtag = find_popular_hashtag(hashtags_list)
    {:noreply, %{hashtags: hashtags_list, popular_hashtag: popular_hashtag}}
  end

  defp find_popular_hashtag(words) do
    words
    |> Enum.group_by(& &1)
    |> Enum.max_by(fn {_, list} -> length(list) end)
    |> elem(0)
  end
end
