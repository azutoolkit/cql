require "../../src/postgres"

# The pool `DB.open` builds, on CQL's native driver whatever claims postgres:// in the spec binary (the pg shard can).
def open_native(url : String, & : DB::Database ->) : Nil
  uri = URI.parse(url)
  driver, params = CQL::Postgres::Driver.new, HTTP::Params.parse(uri.query || "")
  builder = driver.connection_builder(uri)
  database = DB::Database.new(driver.connection_options(params), driver.pool_options(params)) { builder.build }
  yield database
ensure
  database.try &.close
end
