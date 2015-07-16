defmodule EctoTtlTest.MyModel do
  use Ecto.Model
  schema "mymodel" do
    field :name
    field :updated_at, Ecto.DateTime
    field :ttl, :integer, default: 3600
  end
end

defmodule EctoTtlTest.MySecondModel do
  use Ecto.Model
  schema "mysecondmodel" do
    field :name
    field :updated_at, Ecto.DateTime
    field :ttl, :integer, default: 3600
  end
end


defmodule EctoTtlTest do
  use ExUnit.Case
  import Ecto.Query
  alias EctoIt.Repo
  alias EctoTtlTest.MyModel
    alias EctoTtlTest.MySecondModel
  @models [MyModel, MySecondModel]

  setup do
    {:ok, [:ecto_it]} = Application.ensure_all_started(:ecto_it)
    on_exit fn -> :application.stop(:ecto_it) end
  end

  test "time to live" do
    setup_ecto([MyModel])
    assert :ok = Ecto.Ttl.models([MyModel], Repo)

    for i <- 1..20, do: assert %{} = Repo.insert!(%MyModel{name: "testname-#{i}", ttl: 1, updated_at: Ecto.DateTime.utc})
    assert entries = [%MyModel{} | _] = get_model MyModel
    assert 20 = length(entries)

    :timer.sleep(4000)
    assert []                         = get_model MyModel
  end

  test "add models" do
    setup_ecto(@models)
    assert :ok = Ecto.Ttl.models([MyModel], Repo)
    Repo.insert!(%MyModel{name: "add_models_test-1", ttl: 1, updated_at: Ecto.DateTime.utc})
    Repo.insert!(%MySecondModel{name: "add_models_test-1", ttl: 1, updated_at: Ecto.DateTime.utc})
    :timer.sleep 4000
    assert [] = get_model MyModel
    assert [%MySecondModel{}] = get_model MySecondModel
    assert :ok = Ecto.Ttl.add_models(@models, Repo)
    :timer.sleep 4000
    assert [] = get_model MySecondModel
  end
  
  defp get_model(model), do: Repo.all (from m in model)
  defp setup_ecto(models) do
    for m <- models, do: Ecto.Migration.Auto.migrate(Repo, m)
    Application.put_env :ecto_ttl, :cleanup_interval, 1
  end
end
