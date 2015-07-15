defmodule EctoTtlTest.MyModel do
  use Ecto.Model
  schema "mymodel" do
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

  setup do
    {:ok, [:ecto_it]} = Application.ensure_all_started(:ecto_it)
    on_exit fn -> :application.stop(:ecto_it) end
  end

  test "time to live" do
    Ecto.Migration.Auto.migrate(Repo, MyModel)
    Application.put_env :ecto_ttl, :cleanup_interval, 1
    assert :ok = Ecto.Ttl.models([MyModel], Repo)

    assert %{} = Repo.insert!(%MyModel{name: "testsession1", ttl: 1, updated_at: Ecto.DateTime.utc})
    assert [%MyModel{}] = get_model
    :timer.sleep(4000)
    assert []           = get_model
  end

  def get_model, do: Repo.all (from m in MyModel)
end
