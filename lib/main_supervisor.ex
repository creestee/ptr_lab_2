defmodule TwitterSupervisor do
  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, name: __MODULE__)
  end

  def init(_init_arg) do
    children = [
      %{
        id: :mediator,
        start: {LoadBalancer, :start_link, [[]]}
      },
      %{
        id: :sse_client_1,
        start: {SseClient, :start_link, [["localhost:4000/tweets/1", :mediator]]}
      },
      %{
        id: :sse_client_2,
        start: {SseClient, :start_link, [["localhost:4000/tweets/2", :mediator]]}
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
