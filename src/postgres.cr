# Opt-in PostgreSQL developer-experience layer: `require "cql/postgres"`.
#
# Lives next to (and does not replace) `CQL::Migration(V)`, `CQL::Migrator` and
# `CQL::ActiveRecord::Model(Pk)`: models, migrations, database tasks and a health
# report for apps that run on PostgreSQL. `require "cql"` alone never loads it.
require "pg"
require "./cql"
require "./postgres/configuration"
require "./postgres/database/database"
require "./postgres/model/model"
require "./postgres/migrations/migrations"
require "./postgres/database/maintenance"
require "./postgres/database/tasks"
