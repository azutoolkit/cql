require "../database/database"
require "./sql"
require "./executor"
require "./table_builder"
require "./migration"
require "./migrator"

::CQL::Postgres::Database.pending_check = -> { ::CQL::Postgres::Migrator.new.pending_count }
