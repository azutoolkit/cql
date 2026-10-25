require "../spec_helper"

describe "CQL::Schema#transaction nesting" do
  db_file = File.join(Dir.tempdir, "cql_nested_tx_#{Process.pid}_#{Random::Secure.hex(4)}.db")

  schema = CQL::Schema.define(:nested_tx, adapter: CQL::Adapter::SQLite, uri: "sqlite3://#{db_file}") do
    table :nested_rows do
      primary :id, Int32
      column :label, String
    end
  end

  count_rows = -> { schema.exec_query(&.query_one("SELECT COUNT(*) FROM nested_rows", as: Int64)) }
  labels = -> { schema.exec_query(&.query_all("SELECT label FROM nested_rows ORDER BY label", as: String)) }
  # Reads through a separate connection, so it sees only committed rows.
  committed_labels = -> do
    DB.open("sqlite3://#{db_file}", &.query_all("SELECT label FROM nested_rows ORDER BY label", as: String))
  end

  before_each do
    schema.build
    schema.exec("DELETE FROM nested_rows")
  end

  after_all do
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
end
