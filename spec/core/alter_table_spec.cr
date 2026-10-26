require "../spec_helper"

# A fresh SQLite schema per example, holding a `widgets` table with one row, so in-memory changes
# made by `schema.alter` never leak between examples.
private def with_widgets(&)
  db_file = File.join(Dir.tempdir, "cql_alter_table_#{Process.pid}_#{Random::Secure.hex(4)}.db")
  schema = CQL::Schema.define(:alter_table_spec, adapter: CQL::Adapter::SQLite, uri: "sqlite3://#{db_file}") do
    table :widgets do
      primary :id, Int32
      column :name, String
    end
  end
  begin
    schema.widgets.create!
    schema.exec("INSERT INTO widgets (name) VALUES ('first')")
    yield schema
  ensure
    schema.close
    File.delete(db_file) if File.exists?(db_file)
  end
end

private def query_all_strings(schema : CQL::Schema, sql : String) : Array(String)
  schema.exec_query(&.query_all(sql, as: String))
end

# Never connects: `initial_pool_size=0` and nothing is executed.
private def postgres_widgets : CQL::Table
  CQL::Schema.define(:alter_table_pg, "postgres://localhost:1/none?initial_pool_size=0", CQL::Adapter::Postgres) do
    table :widgets do
      primary :id, Int32
      column :name, String
    end
  end.widgets
end

private def cockroach_widgets : CQL::Table
  CQL::Schema.define(:alter_table_cockroach, "cockroachdb://localhost:1/none?initial_pool_size=0", CQL::Adapter::CockroachDB) do
    table :widgets do
      primary :id, Int32
      column :name, String
    end
  end.widgets
end

# A MySQL-dialect schema over a SQLite connection that is never used.
private def mysql_widgets : CQL::Table
  schema = CQL::Schema.new(:alter_table_mysql, "mysql://localhost/cql_spec", CQL::Adapter::MySql,
    source: CQL::DatabaseSource.new(DB.open("sqlite3://%3Amemory%3A?initial_pool_size=0")))
  schema.table :widgets do
    primary :id, Int32
    column :name, String
  end
end

private def alter_sql(table : CQL::Table, adapter : CQL::Adapter, &) : String
  alter = CQL::AlterTable.new(table, table.schema)
  with alter yield
  alter.to_sql(Expression::Generator.new(adapter))
end

describe "CQL::AlterTable" do
  describe "#add_column" do
    it "adds a NOT NULL column with a default to a table that has rows" do
      with_widgets do |schema|
        schema.alter :widgets do
          add_column :quantity, Int32, default: 1, null: false
        end

        schema.exec_query(&.query_one("SELECT quantity FROM widgets", as: Int32)).should eq(1)
      end
    end

    it "creates the index asked for with index: true" do
      with_widgets do |schema|
        schema.alter :widgets do
          add_column :sku, String, null: true, index: true
        end

        query_all_strings(schema, "SELECT name FROM pragma_index_list('widgets')").should contain("idx_widgets_sku")
      end
    end

    it "renders the default and the index on every dialect" do
      with_widgets do |schema|
        alter_sql(schema.widgets, CQL::Adapter::SQLite) { add_column :quantity, Int32, default: 1, null: false, index: true }
          .should eq("ALTER TABLE widgets ADD COLUMN quantity INTEGER DEFAULT 1 NOT NULL;\nCREATE INDEX idx_widgets_quantity ON widgets (quantity);\n")
      end
      alter_sql(postgres_widgets, CQL::Adapter::Postgres) { add_column :quantity, Int32, default: 1, null: false, index: true }
        .should eq("ALTER TABLE widgets ADD COLUMN quantity INTEGER DEFAULT 1 NOT NULL;\nCREATE INDEX idx_widgets_quantity ON widgets (quantity);\n")
      alter_sql(mysql_widgets, CQL::Adapter::MySql) { add_column :label, String, default: "none", index: true }
        .should eq("ALTER TABLE widgets ADD COLUMN label VARCHAR(255) DEFAULT 'none';\nCREATE INDEX idx_widgets_label ON widgets (label);\n")
      alter_sql(cockroach_widgets, CQL::Adapter::CockroachDB) { add_column :quantity, Int32, default: 1, null: false }
        .should eq("ALTER TABLE widgets ADD COLUMN quantity INT4 DEFAULT 1 NOT NULL;\n")
    end

    it "declares a String column's size as its VARCHAR length" do
      alter_sql(postgres_widgets, CQL::Adapter::Postgres) { add_column :code, String, size: 12 }
        .should eq("ALTER TABLE widgets ADD COLUMN code VARCHAR(12);\n")
      alter_sql(mysql_widgets, CQL::Adapter::MySql) { add_column :code, String, size: 12 }
        .should eq("ALTER TABLE widgets ADD COLUMN code VARCHAR(12);\n")
    end

    it "ignores size on a type that has no length" do
      alter_sql(postgres_widgets, CQL::Adapter::Postgres) { add_column :count, Int32, size: 4 }
        .should eq("ALTER TABLE widgets ADD COLUMN count INTEGER;\n")
    end
  end

  describe "column size" do
    it "is the VARCHAR length in CREATE TABLE on PostgreSQL and MySQL" do
      postgres_widgets.schema.table(:accounts) do
        primary :id, Int32
        column :code, String, size: 12
        varchar :name
      end.create_sql.should eq("CREATE TABLE IF NOT EXISTS accounts (id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY, code VARCHAR(12) NOT NULL, name VARCHAR NOT NULL)")

      mysql_widgets.schema.table(:accounts) do
        primary :id, Int32
        column :code, String, size: 12
        varchar :name
        varchar :title, size: 100
      end.create_sql.should eq("CREATE TABLE IF NOT EXISTS accounts (id INT PRIMARY KEY AUTO_INCREMENT, code VARCHAR(12) NOT NULL, name VARCHAR(255) NOT NULL, title VARCHAR(100) NOT NULL)")
    end

    it "keeps SQLite's TEXT, which has no length" do
      with_widgets do |schema|
        schema.table(:accounts) do
          primary :id, Int32
          column :code, String, size: 12
        end.create_sql.should eq("CREATE TABLE IF NOT EXISTS accounts (id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT NOT NULL)")
      end
    end

    it "is kept when MySQL renames the column" do
      accounts = mysql_widgets.schema.table(:accounts) do
        primary :id, Int32
        column :code, String, size: 12
      end

      alter_sql(accounts, CQL::Adapter::MySql) { rename_column :code, :short_code }
        .should eq("ALTER TABLE accounts CHANGE code short_code VARCHAR(12);\n")
    end
  end
end
