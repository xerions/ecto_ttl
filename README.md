EctoTtl
=======

EctoTtl provides a time to live extension for Ecto models.

Usage
-----

Start ecto_ttl and call Ecto.Ttl.models/2.
EctoTtl will only work on models which have the ttl field configured:

field :ttl, :integer

Given entries will be deleted after not being updated for ttl seconds.
