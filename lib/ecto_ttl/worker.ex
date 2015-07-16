defmodule Ecto.Ttl.Worker do
  use GenServer
  @batch_size 10
  @default_timeout 60

  import Ecto.Query

  defmacrop cleanup_interval do
    quote do: Application.get_env(:ecto_ttl, :cleanup_interval, @default_timeout) * 1000
  end

  def start_link, do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def handle_call({:set_models, models}, _from, _state), do: {:reply, :ok, models, cleanup_interval}
  def handle_call({:add_models, models}, _from, state), do: {:reply, :ok, Keyword.merge(state, models), cleanup_interval}
  
  def handle_info(:timeout, models) do
    for model <- models, do: delete_expired(model)
    {:noreply, models, cleanup_interval}
  end

  defp delete_expired({model, repo}), do: delete_expired({model, repo}, check_schema(model))
  defp delete_expired(_, :false), do: :ignore
  defp delete_expired({model, repo}, :true) do
    ignore_newest_seconds = Application.get_env(:ecto_ttl, :ignore_newest_seconds, @default_timeout)
    date_lastrun = :calendar.datetime_to_gregorian_seconds(:erlang.universaltime) - ignore_newest_seconds
                     |> :calendar.gregorian_seconds_to_datetime
                     |> Ecto.DateTime.from_erl
    check_delete_batches(repo, model, date_lastrun)
  end

  defp check_delete_batches(repo, model, date_lastrun), do: check_delete_batches(repo, model, date_lastrun, 0)
  defp check_delete_batches(repo, model, date_lastrun, offset) do
    query = from m in model,
              where: m.ttl > 0 and m.updated_at < ^date_lastrun and m.id > ^offset,
              limit: ^@batch_size,
              select: %{id: m.id, ttl: m.ttl, updated_at: m.updated_at}
              resp = repo.all(query)
    batch_processed =
      for e <- resp, do: check_delete_entry(model, repo, e)
    cond do
      length(batch_processed) < @batch_size -> :ok
      true -> check_delete_batches(repo, model, date_lastrun, List.last(batch_processed))
    end
  end

  defp check_delete_entry(model, repo, entry) do
    current_time_seconds = :erlang.universaltime |> :calendar.datetime_to_gregorian_seconds
    expired_at_seconds = entry.ttl + (entry.updated_at |> Ecto.DateTime.to_erl |> :calendar.datetime_to_gregorian_seconds)
    if current_time_seconds > expired_at_seconds, do: repo.delete!(struct(model, Map.to_list(entry)))
    entry.id
  end

  defp check_schema(model) do
    fields = model.__schema__(:fields)
    :lists.member(:ttl, fields) and :lists.member(:updated_at, fields)
  end
end
