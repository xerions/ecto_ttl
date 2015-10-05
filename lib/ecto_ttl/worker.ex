defmodule Ecto.Ttl.Worker do
  use GenServer
  @default_batch_size 1000
  @default_timeout 60

  import Ecto.Query

  defmacrop cleanup_interval do
    quote do: Application.get_env(:ecto_ttl, :cleanup_interval, @default_timeout) * 1000
  end

  def start_link(models) when is_list(models), do: GenServer.start_link(__MODULE__, models, name: __MODULE__)

  def init(modules), do: {:ok, modules, cleanup_interval}

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
              limit: ^batch_size,
              select: %{id: m.id, ttl: m.ttl, updated_at: m.updated_at}
    resp = repo.all(query)
    {processed, last} = Enum.reduce(resp, {0, nil}, fn(entry, {count, _}) ->
      {count + 1, check_delete_entry(model, repo, entry)}
    end)
    cond do
      processed < batch_size -> :ok
      true -> check_delete_batches(repo, model, date_lastrun, last)
    end
  end

  defp check_delete_entry(model, repo, entry) do
    current_time_seconds = :erlang.universaltime |> :calendar.datetime_to_gregorian_seconds
    expired_at_seconds = entry.ttl + (entry.updated_at |> Ecto.DateTime.to_erl |> :calendar.datetime_to_gregorian_seconds)
    if current_time_seconds > expired_at_seconds, do: callback_delete(repo, model, entry)
    entry.id
  end

  defp check_schema(model) do
    fields = model.__schema__(:fields)
    (:ttl in fields) and (:updated_at in fields)
  end

  defp callback_delete(repo, model, entry) do
    cond do
      function_exported?(model, :ttl_terminate, 2) ->
        handle_delete_callback(repo, model, entry, model.ttl_terminate(repo, entry))
      true ->
        repo.delete!(struct(model, Map.to_list(entry)))
    end
  end

  defp handle_delete_callback(repo, model, entry, :ignore), do: nil
  defp handle_delete_callback(repo, model, entry, :delete), do: repo.delete!(struct(model, Map.to_list(entry)))
  defp handle_delete_callback(repo, model, entry, _), do: repo.delete!(struct(model, Map.to_list(entry)))

  defp batch_size, do: Application.get_env(:ecto_ttl, :batch_size, @default_batch_size)
end
