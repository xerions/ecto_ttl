defmodule Ecto.Ttl.Worker do
  use GenServer
  @timeout 60000

  def start_link, do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def handle_call({:set_models, models}, _from, _state) do
    {:reply, :ok, models, @timeout}
  end

  def handle_info(:timeout, models) do
    for model <- models, do: delete_expired(model)
    {:noreply, models, @timeout}
  end

  defp delete_expired(model) do
    IO.puts to_string(model)
  end
end
