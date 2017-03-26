defmodule EctoTtl.Mixfile do
  use Mix.Project

  def project do
    [app: :ecto_ttl,
     version: "0.0.1",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [applications: [:logger, :ecto]]
  end

  defp deps do
    [{:postgrex, ">= 0.0.0", optional: true},
     {:mariaex, ">= 0.0.0", optional: true},
     {:ecto, ">= 0.13.0"},
     {:ecto_it, ">= 0.1.0", optional: true},
     {:ecto_migrate, ">= 0.4.0"}]
  end
end
