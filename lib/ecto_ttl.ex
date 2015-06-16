defmodule Ecto.Ttl do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec
    tree = [worker(Ecto.Ttl.Worker, [])]
    opts = [name: Ecto.Ttl.Sup, strategy: :one_for_one]
    Supervisor.start_link(tree, opts)
  end

  def models(models) do
    GenServer.call Ecto.Ttl.Worker, {:set_models, models}
  end
end
