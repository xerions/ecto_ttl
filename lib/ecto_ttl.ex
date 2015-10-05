defmodule Ecto.Ttl do
  @moduledoc """
  Ecto plugin to enable time to live functionality for schemas.

  ## Description

  After being started, `Ecto.Ttl.Worker` searches for expired entries in the database every `:cleanup_interval` seconds.
  Only schemas with the `:ttl` field are considered for cleanup.
  The :ttl fields value provides the timespan in seconds after which an entry is being deleted after its `:updated_at` timestamp.

  Optional the implemented Module may export a callback function
  `:ttl_terminate` %{id: id, ttl: ttl, updated_at: updated_at} -> :ignore || :delete
  to customize the workers behaviour.

  ### Usage

      iex> defmodule Test.Repo do
      ...>   use Ecto.Repo, otp_app: :ecto_ttl, adapter: Ecto.Adapters.MySQL
      ...> end
      iex> defmodule Test.Session do
      ...>   use Ecto.Model
      ...>   schema "session" do
      ...>     field :name,    :string
      ...>     field :updated_at, Ecto.DateTime
      ...>     field :ttl,     :integer, default: 3600
      ...>   end
      ...>   def ttl_terminate(%{}), do: :delete
      ...> end
      iex> Application.ensure_all_started(:ecto_ttl)
      {:ok, []}
      iex> Ecto.Ttl.models([Test.Session], Test.Repo)
      :ok
  """
  use Application

  @doc"""
  Configure the set of models and their repository for `Ecto.Ttl.Worker`.

  ## Parameters
  * `models` - A list of modules which use Ecto.Model (models without the `:ttl` field may be included).
  * `repo` - A repository (`Ecto.Repo`) which contains the models provided.

  """
  def models(models, repo), do: GenServer.call(Ecto.Ttl.Worker, {:set_models, Enum.map(models,  &{&1, repo})})

  @doc"""
  Add models to the set of models which `Ecto.Ttl.Worker` considers for deletion.

  ## Parameters
  * `models` - A list of modules which use Ecto.Model (models without the `:ttl` field may be included).
  * `repo` - A repository (`Ecto.Repo`) which contains the models provided.

  """
  def add_models(models, repo), do: GenServer.call(Ecto.Ttl.Worker, {:add_models, Enum.map(models,  &{&1, repo})})
end
