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
        GenServer.cast(self(), {:print, batch})
        {:noreply, {0, batch_size, []}}
      true ->
        {:noreply, {current_capacity + 1, batch_size, [tweet | batch]}}
    end
  end

  def handle_cast({:print, batch}, state) do
    Logger.info "------------ BATCH PRINTING ------------"
    IO.inspect Enum.with_index(batch, fn el, index -> "[#{index + 1}] - #{el}" end)
    Logger.info "------------ BATCH FINISHED ------------"
    {:noreply, state}
  end
end
