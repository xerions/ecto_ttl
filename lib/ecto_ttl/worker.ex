defmodule Ecto.Ttl.Worker do
  use GenServer
  @default_timeout 60

  import Ecto.Query

  defmacrop cleanup_interval do
    quote do: Application.get_env(:ecto_ttl, :cleanup_interval, @default_timeout) * 1000
  end

  def start_link, do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def handle_call({:set_models, models}, _from, _state) do
    {:reply, :ok, models, cleanup_interval}
  end

  def handle_info(:timeout, models) do
    for model <- models, do: delete_expired(model)
    {:noreply, models, cleanup_interval}
  end

  defp delete_expired({model, repo}), do: delete_expired({model, repo}, :lists.member(:ttl, model.__schema__(:fields)))
  defp delete_expired(_, :false), do: :ignore
  defp delete_expired({model, repo}, :true) do
    date_lastrun = :calendar.datetime_to_gregorian_seconds(:erlang.universaltime) - div(cleanup_interval, 1000)
                     |> :calendar.gregorian_seconds_to_datetime
                     |> Ecto.DateTime.from_erl
    query = from m in model,
              #where: m.ttl > 0,
              where: m.ttl > 0 and m.updated_at < ^date_lastrun,
              select: m
    resp = repo.all(query)
    for e <- resp, do: check_delete_entry(model, repo, e)
  end

  defp check_delete_entry(model, repo, entry) do
    :io.format :user, "found deletable entry: ~p~n", [{entry.name, entry.id, Ecto.DateTime.to_string(entry.updated_at), entry.ttl}]
    repo.delete(entry)
  end

end
