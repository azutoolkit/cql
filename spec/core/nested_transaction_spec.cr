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
  # The columns the schema declares for the table, which `alter` changes in memory.
  declared_columns = -> { schema.tables[:nested_alters].columns.keys }
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
    declared_columns.call.should_not contain :added_then_rolled_back
  end

  it "restores the declaration of an alter committed by a savepoint when the outer block raises" do
    expect_raises(Exception, "boom") do
      schema.transaction do
        schema.transaction { schema.alter(:nested_alters) { add_column :added_in_savepoint, String } }
        raise "boom"
      end
    end

    committed_columns.call.should_not contain "added_in_savepoint"
    declared_columns.call.should_not contain :added_in_savepoint
  end

  it "restores a renamed column's declaration when the transaction rolls back on DB::Rollback" do
    declared_before = declared_columns.call

    schema.transaction do
      schema.alter(:nested_alters) { rename_column :label, :title }
      raise DB::Rollback.new
    end

    committed_columns.call.should contain "label"
    declared_columns.call.should eq declared_before
    schema.tables[:nested_alters].columns[:label].name.should eq :label
  end

  it "restores only the savepoint's alter when the savepoint rolls back and the outer one commits" do
    schema.transaction do
      schema.alter(:nested_alters) { add_column :kept_by_outer, String }
      schema.transaction do
        schema.alter(:nested_alters) { add_column :undone_by_savepoint, String }
        raise DB::Rollback.new
      end
    end

    committed_columns.call.should contain "kept_by_outer"
    committed_columns.call.should_not contain "undone_by_savepoint"
    declared_columns.call.should contain :kept_by_outer
    declared_columns.call.should_not contain :undone_by_savepoint
  end

  it "restores the declaration of an alter run under the existing-transaction overload when the owner rolls back" do
    schema.transaction do |tx|
      schema.transaction(tx) { schema.alter(:nested_alters) { add_column :added_under_overload, String } }
      raise DB::Rollback.new
    end

    committed_columns.call.should_not contain "added_under_overload"
    declared_columns.call.should_not contain :added_under_overload
  end

  it "restores the declaration when the alter block raises before any SQL runs" do
    expect_raises(Exception, "boom") do
      schema.alter(:nested_alters) do
        add_column :declared_before_failure, String
        raise "boom"
      end
    end

    declared_columns.call.should_not contain :declared_before_failure
  end

  it "restores a renamed table's declaration when the transaction rolls back" do
    table = schema.tables[:nested_alters]

    schema.transaction do
      schema.alter(:nested_alters) { rename_table :nested_renamed }
      raise DB::Rollback.new
    end

    schema.tables[:nested_alters]?.should be(table)
    schema.tables.has_key?(:nested_renamed).should be_false
    table.table_name.should eq :nested_alters
  end

  it "keeps the declaration of a committed alter when a later transaction rolls back" do
    schema.transaction { schema.alter(:nested_alters) { add_column :kept_after_commit, String } }
    expect_raises(Exception, "boom") { schema.transaction { raise "boom" } }

    declared_columns.call.should contain :kept_after_commit
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

  it "rolls back DDL run in a ddl_transaction when the block raises" do
    expect_raises(Exception, "boom") do
      schema.ddl_transaction do
        schema.exec("CREATE TABLE ddl_tx_probe (id INTEGER)")
        raise "boom"
      end
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

describe "CQL::Schema#transaction when the commit fails" do
  it "restores the declaration of an alter in the transaction" do
    db_file = File.join(Dir.tempdir, "cql_commit_fails_#{Process.pid}_#{Random::Secure.hex(4)}.db")
    schema = CQL::Schema.define(:commit_fails, adapter: CQL::Adapter::SQLite, uri: "sqlite3://#{db_file}?foreign_keys=1") do
      table :parents { primary :id, Int32 }
      table :children do
        primary :id, Int32
        column :parent_id, Int32
      end
    end
    begin
      schema.parents.create!
      schema.exec("CREATE TABLE children (id INTEGER PRIMARY KEY, parent_id INTEGER NOT NULL " \
                  "REFERENCES parents (id) DEFERRABLE INITIALLY DEFERRED)")

      # The deferred foreign key is checked at COMMIT, so the block finishes and the commit itself fails.
      expect_raises(Exception, /FOREIGN KEY/) do
        schema.transaction do
          schema.alter(:children) { add_column :note, String, null: true }
          schema.exec("INSERT INTO children (id, parent_id) VALUES (1, 999)")
        end
      end

      schema.children.columns.keys.should eq [:id, :parent_id]
    ensure
      begin
        schema.close
      rescue SQLite3::Exception # SQLite keeps a transaction open after a failed COMMIT; closing reports it again
      end
      File.delete(db_file) if File.exists?(db_file)
    end
  end
end
