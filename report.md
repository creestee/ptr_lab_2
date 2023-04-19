# FAF.PTR16.1 -- Project 1
> **Performed by:** Cristian Ionel, group FAF-202
> **Verified by:** asist. univ. Alexandru Osadcenco

## P1W1

**Task 1** -- Write an actor that would read SSE streams. The SSE streams for this lab
are available on Docker Hub at alexburlacu/rtp-server, courtesy of our beloved FAFer Alex
Burlacu.

```elixir
defmodule SseClient do
  use GenServer
  require Logger

  def start_link([url, pid_mediator]) do
    GenServer.start_link(__MODULE__, url: url, pid_mediator: pid_mediator)
  end

  def init([url: url, pid_mediator: pid_mediator]) do
    Logger.info("Connecting to stream...")
    HTTPoison.get!(url, [], [recv_timeout: :infinity, stream_to: self()])
    {:ok, pid_mediator}
  end

  def handle_info(%HTTPoison.AsyncChunk{chunk: ""}, pid_mediator) do
    {:noreply, pid_mediator}
  end

  def handle_info(%HTTPoison.AsyncChunk{chunk: chunk}, pid_mediator) do
    case Regex.run(~r/data: ({.+})\n\n$/, chunk) do
      [_, data] ->
        GenServer.cast(pid_mediator, {:mediate, data})
    end
    {:noreply, pid_mediator}
  end

  def handle_info(%HTTPoison.AsyncStatus{} = _status, state) do
    {:noreply, state}
  end

  def handle_info(%HTTPoison.AsyncHeaders{} = _headers, state) do
    {:noreply, state}
  end
end
```

`SseClient` is an actor that reads Server-Sent Events (SSE) streams. It connects to a given URL using HTTPoison, and whenever it receives data from the stream, it checks the format of the data using a regular expression, and sends the data to another process using `GenServer.cast`. The implementation also handles empty chunks, status, and headers. This module provides an easy way to read SSE streams and process the data using Elixir's built-in GenServer behavior.

**Task 2** -- Create an actor that would print on the screen the tweets it receives from
the SSE Reader. You can only print the text of the tweet to save on screen space.

```elixir
defmodule Printer do
  use GenServer
  require Logger

  ...
  
  def start(name) do
    GenServer.start_link(__MODULE__, name, name: name)
  end

  def init(printer_id) do
    {:ok, printer_id}
  end

  def handle_cast({:print, message}, printer_id) do

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
```

This Elixir module defines an actor, `Printer`, which prints tweets received from an SSE Reader. It uses the built-in `GenServer` behavior to manage state and handle messages. 

Once initialized, the `Printer` process waits for messages sent to it using the `GenServer.cast` function. The `handle_cast` function is called whenever a message is received by the process. The function decodes the message using the `JSON.decode` function and extracts the tweet text. It then prints the tweet text to the console. If the tweet has any hashtags, the function sends them to another actor, analyzer, using `GenServer.cast`.

**Task 3** -- Create a second Reader actor that will consume the second stream provided by
the Docker image. Send the tweets to the same Printer actor.

```elixir
defmodule MainSupervisor do
  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, name: __MODULE__)
  end

  def init(_init_arg) do
    children = [
      ...,
      %{
        id: :sse_client_1,
        start: {SseClient, :start_link, [["localhost:4000/tweets/1", :mediator]]}
      },
      %{
        id: :sse_client_2,
        start: {SseClient, :start_link, [["localhost:4000/tweets/2", :mediator]]}
      },
      ...
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

For this task I created another actor (`Main Supervisor`) which supervises these 2 Reader actors (`SSE Client`).

**Task 4** -- Continue your Printer actor. Simulate some load on the actor by sleeping every
time a tweet is received. Suggested time of sleep – 5ms to 50ms. Consider using Poisson
distribution. Sleep values / distribution parameters need to be parameterizable.

```elixir
defmodule Printer do
  use GenServer
  require Logger

  @range_multiplier 6

  ...

  def handle_cast({:print, message}, printer_id) do
    Process.sleep(trunc(Statistics.Distributions.Poisson.rand(25)) * @range_multiplier)
    ...
  end
end
```

The `Printer` actor has been extended to simulate some load on the actor by sleeping every time a tweet is received. A Poisson distribution is used to calculate the sleep time, with a suggested time range of 5ms to 50ms. The `@range_multiplier` constant is used to adjust the range of the sleep time. The sleep time is calculated by taking a random value from the Poisson distribution with a mean value of 25, truncating it to an integer, and multiplying it by the `@range_multiplier`. This makes the sleep time parameterizable by changing the value of `@range_multiplier`.

**Task 5** -- Create an actor that would print out every 5 seconds the most popular hashtag
in the last 5 seconds. Consider adding other analytics about the stream.

```elixir
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
    Logger.info("The most popular hashtag in the last 5 seconds is: #{state.popular_hashtag}", ansi_color: :blue)
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
```

The `AnalyzeTweets` actor analyzes incoming tweets to determine the most popular hashtag in the last 5 seconds and prints it every 5 seconds. It uses a `GenServer` and implements the `handle_info` and `handle_cast` callbacks to process the messages it receives. The `find_popular_hashtag` function uses `Enum.group_by` to group the hashtags and `Enum.max_by` to find the group with the most hashtags.

## P1W2

**Task 1** -- Create a Worker Pool to substitute the Printer actor from previous week. The
pool will contain 3 copies of the Printer actor which will be supervised by a Pool Supervisor.
Use the one-for-one restart policy.

```elxir
defmodule WorkerPool do
  use Supervisor

  def start_link(workers_count) do
    Supervisor.start_link(__MODULE__, workers_count, name: __MODULE__)
  end

  def init(workers_count) do
    children = Enum.map(1..workers_count, fn x ->
          %{id: x, start: {Printer, :start, [:"printer_#{x}"] } } end) ++
          [%{id: :analyzer, start: {AnalyzeTweets, :start, [:analyzer]}}]
    Supervisor.init(children, strategy: :one_for_one)
  end

end
```

The above code defines a module `WorkerPool` that starts a supervisor process to manage a pool of `Printer` workers and an `AnalyzeTweets` worker. The init function takes a number of workers as an argument, creates child processes for each worker, and specifies the restart policy as `one-for-one`. The `start_link` function starts the supervisor with the specified child processes. This Worker Pool can be used to distribute work among multiple worker processes to improve performance and resilience of the system.

**Task 2** -- Create an actor that would mediate the tasks being sent to the Worker Pool.
Any tweet that this actor receives will be sent to the Worker Pool in a Round Robin fashion.
Direct the Reader actor to sent it’s tweets to this actor.

```elixir
defmodule LoadBalancer do
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
```

This is a module named `LoadBalancer` that mediates the tasks being sent to the worker pool. Each message is sent to the next printer in the sequence, wrapping around to the first printer once the last printer is reached. After sending the message to the printer, the state is incremented by 1, wrapping around to 1 once it reaches `@workers_count`.

**Task 3** -- Continue your Worker actor. Occasionally, the SSE events will contain a “kill
message”. Change the actor to crash when such a message is received. Of course, this should
trigger the supervisor to restart the crashed actor.

```elixir
defmodule Printer do
  use GenServer
  require Logger

  ...

  def handle_cast({:print, message}, printer_id) do
    ...

    case JSON.decode(message) do
      ...

      {:error, _} ->
        Logger.warn("#{printer_id} has crashed...")
        Process.exit(self(), :kill)
    end
  end
end
```

The `Printer` actor now checks the JSON message it receives and if there is an error in decoding it (when the message in the chunk is `panic`), it logs a warning message saying that it has crashed and exits with the `:kill` reason. This will trigger the supervisor to restart the crashed actor.

**Task 4** -- Continue your Load Balancer actor. Modify the actor to implement the “Least
connected” algorithm for load balancing (or other interesting algorithm). Refer to this article
by Tony Allen.

```elixir
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
```

This code updates `LoadBalancer` actor to use the "Least connected" algorithm to balance the load between the three Printer actors in the Worker Pool. When a tweet is received, the `handle_cast` function sends it to the Printer actor with the smallest message queue, as determined by the `smallest_queue_pid` function. This function filters out any `Printer` actors that are not running, then maps over the remaining ones to retrieve their message queue length using `Process.info`. It then returns the name of the `Printer` actor with the smallest message queue. This ensures that new tweets are sent to the `Printer` actor with the least amount of work to do, and helps to balance the load evenly across all three `Printer` actors.

## P1W3

**Task 1** -- Continue your Worker actor. Any bad words that a tweet might contain
mustn’t be printed. Instead, a set of stars should appear, the number of which corresponds to
the bad word’s length. Consult the Internet for a list of bad words.

```elixir
defmodule Printer do
  use GenServer
  require Logger

  ...

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
    
    ...
    
    json_bad_words = load_json("./lib/util/badwords.json")["en"] ++
                        load_json("./lib/util/badwords.json")["es"]

    IO.puts("#{printer_id} -- #{filter_bad_words(chunk_result["message"]["tweet"]["text"], json_bad_words)}")

    ...

  end
end
```

A new function `filter_bad_words` is added to the `Printer` module, which receives a string (str) and a list of bad words (bad_words). The function splits the input string into a list of words using the whitespace as a delimiter, maps over the list of words, and checks if the word is a bad word by using the `Enum.member?` function. If the word is a bad word, it replaces the word with a string of asterisks (*) that has the same length as the bad word using the `String.duplicate` function. Finally, the function joins the list of words back into a string using whitespace as a delimiter and returns the resulting string.

In the `handle_cast` function, the `json_bad_words` variable is assigned by loading two JSON files that contain lists of bad words in English and Spanish. The `filter_bad_words` function is then called with the tweet text and the `json_bad_words` list, and the resulting string is printed to the console with the corresponding printer ID. This implementation replaces any bad words in the tweet with asterisks.

**Task 2** -- Create an actor that would manage the number of Worker actors in the Worker
Pool. When the actor detects an increase in incoming tasks, it should instruct the Worker Pool
to also increase the number of workers. Conversely, if the number of tasks in the stream is low,
the actor should dictate to reduce the number of workers (down to a certain limit). The limit,
and any other parameters of this actor, should of course be parameterizable.

```elixir
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
        Logger.info("\e[30;144;255mAdded worker:\e[0m :printer_#{current_num_children + 1}")

      current_avg_tasks < average_num_tasks && current_num_children > min_workers_limit ->
        Supervisor.terminate_child(WorkerPool, current_num_children)
        Supervisor.delete_child(WorkerPool, current_num_children)
        Logger.info("\e[210;4;45mRemoved worker:\e[0m :printer_#{current_num_children}")

      true ->
        nil
    end

    Logger.info %{
      children_alive: current_num_children,
      current_avg_tasks: current_avg_tasks
    }

    Process.send_after(__MODULE__, :check, @delay_time)
    {:noreply, {min_workers_limit, max_workers_limit, average_num_tasks}}
  end
end
```

The `PoolManager` module is an actor that manages the number of `Worker` actors in the `WorkerPool`. It receives the minimum and maximum number of workers allowed and the average number of tasks, which is used to dynamically adjust the number of workers. The `handle_info` callback function is triggered every `@delay_time` seconds, and it calculates the current number of tasks in the message queue, the current number of children, and the average number of tasks per child. If the number of children is outside the allowed range, the manager adds or removes children accordingly. If the current average tasks are above or below the average_num_tasks limit, the manager adds or removes a child, respectively. Finally, it logs information about the current number of children and the average number of tasks per child.

## P1W4

**Task 1** -- Continue your Worker actor. Besides printing out the redacted tweet text,
the Worker actor must also calculate two values: the Sentiment Score and the Engagement
Ratio of the tweet. To compute the Sentiment Score per tweet you should calculate the mean
of emotional scores of each word in the tweet text. A map that links words with their scores is
provided as an endpoint in the Docker container. If a word cannot be found in the map, it’s
emotional score is equal to 0.

```elixir
defmodule Printer do
  use GenServer
  require Logger

  ...

  def handle_cast({:print, message}, printer_id) do
    
    ...
    
    text = filter_bad_words(chunk_result["message"]["tweet"]["text"], load_json("./lib/util/badwords.json")["en"])
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
    
    ...

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
```

In the `Printer` module it is calculated the Sentiment Score and Engagement Ratio of the tweet. To calculate the Sentiment Score, the tweet text is splitted into words, then it is used `Enum.reduce` to sum the emotional scores of each word using the `emotional_score_map` function, which retrieves the emotional score map from an HTTP endpoint. If a word is not found in the map, its score is set to 0. The average score is then calculated by dividing the sum of scores by the length of the words list.

To calculate the Engagement Ratio, we need number of retweets and favorites of the tweet, and the number of followers of the tweet author. If the author has 0 followers, the Engagement Ratio is set to 0, otherwise it is calculated as the sum of retweets and favorites divided by the number of followers.

## P1W5

**Task 1** -- Create an actor that would collect the redacted tweets from Workers and
would print them in batches. Instead of printing the tweets, the Worker should now send them
to the Batcher, which then prints them. The batch size should be parametrizable.

```elixir
defmodule Batcher do
  use GenServer
  require Logger

  def start_link(batch_size) do
    GenServer.start_link(__MODULE__, batch_size, name: :batcher)
  end

  def init(batch_size) do
    {:ok, {0, batch_size, []}}
  end

  def handle_cast({:collect, tweet}, {current_capacity, batch_size, batch}) do
    cond do
      current_capacity >= batch_size ->
        Logger.info "------------ BATCH PRINTING ------------"
        IO.inspect Enum.with_index(batch, fn el, index -> "[#{index + 1}] - #{el}" end)
        Logger.info "------------ BATCH FINISHED ------------"
        {:noreply, {0, batch_size, []}}
      true ->
        {:noreply, {current_capacity + 1, batch_size, [tweet | batch]}}
    end
  end
end
```

This is the implementation of the `Batcher` actor that collects the redacted tweets from `Workers` and prints them in batches. The batch size is parametrizable and is passed as an argument to the `start_link` function. In the `init` function, the actor initializes the state to start with a capacity of 0 and an empty batch. In the `handle_cast` function, the actor receives a tuple containing the `:collect` message and the tweet, and it checks if the current capacity of the batch is equal to the batch size. If it is, then it prints the batch and resets the state to start with a capacity of 0 and an empty batch. If not, it adds the tweet to the batch and increases the capacity by 1. 

## Conclusion

Throughout these tasks, I have learned a lot about stream processing in Elixir. Starting from reading tweets from a server and filtering them based on some conditions. I also learned how to use the HTTPoison library to make HTTP requests and receive JSON responses as chunks of data from a server.
Overall, I gained a better understanding of how to build scalable and fault-tolerant stream processing systems in Elixir, and how to leverage the power of functional programming and the Actor model to achieve that.

## Bibliography

1. https://stackoverflow.com/questions/67739157/elixir-how-to-consume-a-stream-of-server-sent-events-as-a-client
2. https://www.poeticoding.com/download-large-files-with-httpoison-async-requests/
3. https://blog.envoyproxy.io/examining-load-balancing-algorithms-with-envoy-1be643ea121c
4. https://elixirforum.com/t/speculative-execution-implementation-how-do-you-force-an-actor-to-stop-the-process-and-move-on/54717