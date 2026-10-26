require "../spec_helper"

describe "CQL::Schema#transaction nesting" do
  db_file = File.join(Dir.tempdir, "cql_nested_tx_#{Process.pid}_#{Random::Secure.hex(4)}.db")

  schema = CQL::Schema.define(:nested_tx, adapter: CQL::Adapter::SQLite, uri: "sqlite3://#{db_file}") do
    table :nested_rows do
      primary :id, Int32
      column :label, String
    end

    table :nested_alters do
      primary :id, Int32
      column :label, String
    end
  end

  # Speaks MySQL's dialect but runs on the SQLite file, so a spec can open a transaction around DDL.
  mysql_schema = CQL::Schema.new(:nested_tx_mysql, "mysql://localhost/cql_spec", CQL::Adapter::MySql,
    source: CQL::DatabaseSource.new(DB.open("sqlite3://#{db_file}")))
  mysql_schema.table :nested_alters do
    primary :id, Int32
    column :label, String
  end

  count_rows = -> { schema.exec_query(&.query_one("SELECT COUNT(*) FROM nested_rows", as: Int64)) }
  labels = -> { schema.exec_query(&.query_all("SELECT label FROM nested_rows ORDER BY label", as: String)) }
  # Reads through a separate connection, so it sees only committed rows.
  committed_labels = -> do
    DB.open("sqlite3://#{db_file}", &.query_all("SELECT label FROM nested_rows ORDER BY label", as: String))
  end
  # Reads through a separate connection, so it sees only committed schema changes.
  committed_columns = -> do
    DB.open("sqlite3://#{db_file}", &.query_all("SELECT name FROM pragma_table_info('nested_alters')", as: String))
  end
  # Reads through a separate connection, so it sees only committed schema changes.
  committed_probe_tables = -> do
    DB.open("sqlite3://#{db_file}", &.query_all("SELECT name FROM sqlite_master WHERE name = 'ddl_tx_probe'", as: String))
  end

  before_each do
    schema.build
    schema.exec("DELETE FROM nested_rows")
    schema.exec("DROP TABLE IF EXISTS ddl_tx_probe")
  end

  after_all do
    mysql_schema.close
    ["", "-wal", "-shm", "-journal"].each do |suffix|
      path = db_file + suffix
      File.delete(path) if File.exists?(path)
    end
  end

  it "commits a plain transaction" do
    schema.transaction { schema.exec("INSERT INTO nested_rows (label) VALUES ('A')") }

    labels.call.should eq ["A"]
  end

  it "rolls back a plain transaction on DB::Rollback" do
    schema.transaction do
      schema.exec("INSERT INTO nested_rows (label) VALUES ('A')")
      raise DB::Rollback.new
    end

    count_rows.call.should eq 0
  end

  it "rolls back a plain transaction when the block raises" do
    expect_raises(Exception, "boom") do
      schema.transaction do
        schema.exec("INSERT INTO nested_rows (label) VALUES ('A')")
        raise "boom"
      end
    end

    count_rows.call.should eq 0
  end

  it "runs the inner transaction on the outer transaction's connection" do
    outer_connection = nil
    inner_connection = nil

    schema.transaction do |outer|
      outer_connection = outer.connection
      schema.transaction { |inner| inner_connection = inner.connection }
    end

    inner_connection.should_not be_nil
    inner_connection.not_nil!.same?(outer_connection.not_nil!).should be_true
  end

  it "discards the inner writes when the outer transaction rolls back" do
    schema.transaction do
      schema.exec("INSERT INTO nested_rows (label) VALUES ('A')")
      schema.transaction { schema.exec("INSERT INTO nested_rows (label) VALUES ('B')") }
      raise DB::Rollback.new
    end

    count_rows.call.should eq 0
  end

  it "discards the inner writes when the outer block raises" do
    expect_raises(Exception, "boom") do
      schema.transaction do
        schema.exec("INSERT INTO nested_rows (label) VALUES ('A')")
        schema.transaction { schema.exec("INSERT INTO nested_rows (label) VALUES ('B')") }
        raise "boom"
      end
    end

    count_rows.call.should eq 0
  end

  it "keeps the outer writes when only the inner transaction rolls back" do
    schema.transaction do
      schema.exec("INSERT INTO nested_rows (label) VALUES ('A')")
      schema.transaction do
        schema.exec("INSERT INTO nested_rows (label) VALUES ('B')")
        raise DB::Rollback.new
      end
    end

    labels.call.should eq ["A"]
  end

  it "keeps the outer writes when the inner error is rescued in the outer block" do
    schema.transaction do
      schema.exec("INSERT INTO nested_rows (label) VALUES ('A')")
      begin
        schema.transaction do
          schema.exec("INSERT INTO nested_rows (label) VALUES ('B')")
          raise "inner failure"
        end
      rescue ex
        ex.message.should eq "inner failure"
      end
    end

    labels.call.should eq ["A"]
  end

  it "commits both writes when neither transaction rolls back" do
    schema.transaction do
      schema.exec("INSERT INTO nested_rows (label) VALUES ('A')")
      schema.transaction { schema.exec("INSERT INTO nested_rows (label) VALUES ('B')") }
    end

    labels.call.should eq ["A", "B"]
  end

  it "commits two sequential inner transactions in one outer block" do
    schema.transaction do
      schema.transaction { schema.exec("INSERT INTO nested_rows (label) VALUES ('A')") }
      schema.transaction { schema.exec("INSERT INTO nested_rows (label) VALUES ('B')") }
    end

    labels.call.should eq ["A", "B"]
  end

  it "undoes only the innermost transaction of three levels when it rolls back" do
    schema.transaction do
      schema.exec("INSERT INTO nested_rows (label) VALUES ('A')")
      schema.transaction do
        schema.exec("INSERT INTO nested_rows (label) VALUES ('B')")
        schema.transaction do
          schema.exec("INSERT INTO nested_rows (label) VALUES ('C')")
          raise DB::Rollback.new
        end
      end
    end

    labels.call.should eq ["A", "B"]
  end

  it "nests a schema.transaction inside the existing-transaction overload" do
    schema.transaction do |tx|
      schema.transaction(tx) do
        schema.exec("INSERT INTO nested_rows (label) VALUES ('A')")
        schema.transaction do
          schema.exec("INSERT INTO nested_rows (label) VALUES ('B')")
          raise DB::Rollback.new
        end
      end
    end

    labels.call.should eq ["A"]
  end

  it "still isolates a nested rollback after the outer transaction was committed by hand" do
    schema.transaction do |tx|
      tx.commit
      schema.transaction do
        schema.exec("INSERT INTO nested_rows (label) VALUES ('A')")
        raise DB::Rollback.new
      end
    end
    schema.exec("INSERT INTO nested_rows (label) VALUES ('Z')")

    committed_labels.call.should eq ["Z"]
  end

  it "still isolates a nested rollback after the outer transaction was rolled back by hand" do
    schema.transaction do |tx|
      tx.rollback
      schema.transaction do
        schema.exec("INSERT INTO nested_rows (label) VALUES ('A')")
        raise DB::Rollback.new
      end
    end
    schema.exec("INSERT INTO nested_rows (label) VALUES ('Z')")

    committed_labels.call.should eq ["Z"]
  end

  it "keeps later writes in the outer transaction after the inner one was rolled back by hand" do
    schema.transaction do
      schema.transaction do |inner|
        inner.rollback
        schema.exec("INSERT INTO nested_rows (label) VALUES ('A')")
        schema.transaction { schema.exec("INSERT INTO nested_rows (label) VALUES ('B')") }
      end
      raise DB::Rollback.new
    end

    count_rows.call.should eq 0
  end

  it "keeps later writes in the outer transaction after the inner one was committed by hand" do
    schema.transaction do
      schema.transaction do |inner|
        inner.commit
        schema.exec("INSERT INTO nested_rows (label) VALUES ('A')")
        schema.transaction { schema.exec("INSERT INTO nested_rows (label) VALUES ('B')") }
      end
      raise DB::Rollback.new
    end

    count_rows.call.should eq 0
  end

  it "returns to the outer transaction after a rescued inner error" do
    schema.transaction do
      begin
        schema.transaction do
          schema.exec("INSERT INTO nested_rows (label) VALUES ('B')")
          raise "inner failure"
        end
      rescue
      end
      schema.exec("INSERT INTO nested_rows (label) VALUES ('A')")
      committed_labels.call.should be_empty
    end

    committed_labels.call.should eq ["A"]
  end

  it "runs later writes outside the transaction that raised" do
    expect_raises(Exception, "boom") do
      schema.transaction do
        schema.exec("INSERT INTO nested_rows (label) VALUES ('lost')")
        raise "boom"
      end
    end

    schema.exec("INSERT INTO nested_rows (label) VALUES ('A')")
    DB.open("sqlite3://#{db_file}") do |other|
      other.query_one("SELECT COUNT(*) FROM nested_rows", as: Int64).should eq 1
    end
  end

  it "keeps each fiber's queries on its own transaction while other fibers run outside one" do
    open_tx_connections = [] of DB::Connection
    wrong_connections = [] of String
    plain_queries_beside_open_tx = 0
    done = Channel(Nil).new
    fibers = 6

    fibers.times do |i|
      spawn do
        3.times do
          if i.even?
            schema.transaction do |tx|
              open_tx_connections << tx.connection
              Fiber.yield
              schema.exec_query { |conn| wrong_connections << "tx fiber #{i}" unless conn.same?(tx.connection) }
              Fiber.yield
              open_tx_connections.reject!(&.same?(tx.connection))
            end
          else
            plain_queries_beside_open_tx += 1 unless open_tx_connections.empty?
            schema.exec_query { |conn| wrong_connections << "plain fiber #{i}" if open_tx_connections.any?(&.same?(conn)) }
            Fiber.yield
          end
        end
      rescue ex
        wrong_connections << "fiber #{i} raised #{ex.message}"
      ensure
        done.send(nil)
      end
    end
    fibers.times { done.receive }

    plain_queries_beside_open_tx.should be > 0
    wrong_connections.should be_empty
  end

  it "alters a table inside a transaction and commits the column with it" do
    schema.transaction { schema.alter(:nested_alters) { add_column :added_in_transaction, String } }

    committed_columns.call.should contain "added_in_transaction"
  end

  it "discards an alter when the outer transaction block raises" do
    expect_raises(Exception, "boom") do
      schema.transaction do
        schema.alter(:nested_alters) { add_column :added_then_rolled_back, String }
        raise "boom"
      end
    end

    committed_columns.call.should_not contain "added_then_rolled_back"
  end

  it "alters a table outside a transaction" do
    schema.alter(:nested_alters) { add_column :added_outside_transaction, String }

    committed_columns.call.should contain "added_outside_transaction"
  end

  it "refuses an alter inside a transaction on a dialect whose DDL commits implicitly" do
    expect_raises(CQL::DialectError, /MySQL/) do
      mysql_schema.transaction do
        mysql_schema.exec("INSERT INTO nested_rows (label) VALUES ('kept_out')")
        mysql_schema.alter(:nested_alters) { add_column :mysql_nested, String }
      end
    end

    committed_labels.call.should be_empty
    committed_columns.call.should_not contain "mysql_nested"
  end

  it "alters outside a transaction on a dialect whose DDL commits implicitly" do
    mysql_schema.alter(:nested_alters) { add_column :mysql_outside_transaction, String }

    committed_columns.call.should contain "mysql_outside_transaction"
  end

  it "drops a table outside a transaction on a dialect whose DDL commits implicitly" do
    mysql_schema.nested_alters.drop!

    committed_columns.call.should be_empty
  end

  it "refuses create! inside a transaction on a dialect whose DDL commits implicitly" do
    count_queries(:ddl) do
      expect_raises(CQL::DialectError, /MySQL/) { mysql_schema.transaction { mysql_schema.nested_alters.create! } }
    end.should be_empty
  end

  it "refuses drop! inside a transaction on a dialect whose DDL commits implicitly" do
    count_queries(:ddl) do
      expect_raises(CQL::DialectError, /MySQL/) { mysql_schema.transaction { mysql_schema.nested_alters.drop! } }
    end.should be_empty

    committed_columns.call.should_not be_empty
  end

  it "refuses truncate! inside a transaction on a dialect whose DDL commits implicitly" do
    count_queries(:ddl) do
      expect_raises(CQL::DialectError, /MySQL/) { mysql_schema.transaction { mysql_schema.nested_alters.truncate! } }
    end.should be_empty

    mysql_schema.tables[:nested_alters]?.should_not be_nil
  end

  it "refuses build inside a transaction on a dialect whose DDL commits implicitly" do
    count_queries(:ddl) do
      expect_raises(CQL::DialectError, /MySQL/) { mysql_schema.transaction { mysql_schema.build } }
    end.should be_empty
  end

  it "rolls back DDL run in a ddl_transaction when the block raises" do
    expect_raises(Exception, "boom") do
      schema.ddl_transaction do
        schema.exec("CREATE TABLE ddl_tx_probe (id INTEGER)")
        raise "boom"
      end
    end

    committed_probe_tables.call.should be_empty
  end

  it "discards a create! when the outer transaction block raises" do
    probe = CQL::Table.new(:ddl_tx_probe, schema)
    probe.primary :id, Int32

    begin
      expect_raises(Exception, "boom") do
        schema.transaction do
          probe.create!
          raise "boom"
        end
      end
    ensure
      schema.tables.delete(:ddl_tx_probe)
    end

    committed_probe_tables.call.should be_empty
  end

  it "builds every table in one transaction, so a failing table rolls back the tables before it" do
    broken = CQL::Schema.define(:nested_tx_broken, adapter: CQL::Adapter::SQLite, uri: "sqlite3://#{db_file}") do
      table :ddl_tx_probe do
        primary :id, Int32
      end

      table :ddl_tx_broken do
        primary :id, Int32
        check_constraint "not valid sql ("
      end
    end

    begin
      expect_raises(SQLite3::Exception) { broken.build }
    ensure
      broken.close
    end

    committed_probe_tables.call.should be_empty
  end

  it "runs a ddl_transaction block bare outside a transaction on a dialect whose DDL commits implicitly" do
    events = [] of CQL::Telemetry::TransactionEvent
    CQL::Telemetry.subscribe_transactions("ddl_transaction_spec") { |event| events << event }
    ran = false

    begin
      mysql_schema.ddl_transaction { ran = true }
    ensure
      CQL::Telemetry.unsubscribe_transactions("ddl_transaction_spec")
    end

    ran.should be_true
    events.should be_empty
  end
end
