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

    it "restores the declaration when a later statement of the alter fails" do
      with_widgets do |schema|
        schema.exec("CREATE INDEX idx_widgets_status ON widgets (name)")

        expect_raises(Exception, /idx_widgets_status/) do
          schema.alter :widgets do
            add_column :status, String, null: true, index: true
          end
        end

        query_all_strings(schema, "SELECT name FROM pragma_table_info('widgets')").should eq(["id", "name"])
        schema.widgets.columns.keys.should eq([:id, :name])
      end
    end

    it "adds a column whose default holds a statement separator" do
      with_widgets do |schema|
        schema.alter :widgets do
          add_column :note, String, null: false, default: "a;\nb"
        end

        schema.exec_query(&.query_one("SELECT note FROM widgets", as: String)).should eq("a;\nb")
      end
    end
  end

  describe "string defaults" do
    it "keeps a default that tries to close its MySQL literal inside that literal" do
      alter_sql(mysql_widgets, CQL::Adapter::MySql) { add_column :status, String, default: "\\';\nDROP TABLE users;\n--" }
        .should eq("ALTER TABLE widgets ADD COLUMN status VARCHAR(255) DEFAULT '\\\\'';\nDROP TABLE users;\n--';\n")
    end

    it "escapes backslashes and NUL in a MySQL default, where they are escape characters" do
      alter_sql(mysql_widgets, CQL::Adapter::MySql) { add_column :path, String, default: "C:\\" }
        .should eq("ALTER TABLE widgets ADD COLUMN path VARCHAR(255) DEFAULT 'C:\\\\';\n")
      alter_sql(mysql_widgets, CQL::Adapter::MySql) { add_column :path, String, default: "a\0b" }
        .should eq("ALTER TABLE widgets ADD COLUMN path VARCHAR(255) DEFAULT 'a\\0b';\n")
      mysql_widgets.schema.table(:accounts) do
        primary :id, Int32
        column :path, String, default: "C:\\"
      end.create_sql.should contain("path VARCHAR(255) DEFAULT 'C:\\\\' NOT NULL")
    end

    it "writes a PostgreSQL default without backslashes as a plain literal" do
      alter_sql(postgres_widgets, CQL::Adapter::Postgres) { add_column :name, String, default: "it's" }
        .should eq("ALTER TABLE widgets ADD COLUMN name VARCHAR DEFAULT 'it''s';\n")
    end

    it "writes a PostgreSQL default with backslashes as an E'' literal, whatever standard_conforming_strings is" do
      alter_sql(postgres_widgets, CQL::Adapter::Postgres) { add_column :path, String, default: "C:\\ it's" }
        .should eq("ALTER TABLE widgets ADD COLUMN path VARCHAR DEFAULT E'C:\\\\ it''s';\n")
      alter_sql(cockroach_widgets, CQL::Adapter::CockroachDB) { add_column :path, String, default: "C:\\" }
        .should eq("ALTER TABLE widgets ADD COLUMN path VARCHAR DEFAULT E'C:\\\\';\n")
    end

    it "leaves SQLite backslashes alone, where they are not escape characters" do
      with_widgets do |schema|
        schema.alter :widgets do
          add_column :path, String, default: "C:\\ it's"
        end

        schema.exec_query(&.query_one("SELECT path FROM widgets", as: String)).should eq("C:\\ it's")
      end
    end
  end

  describe "time defaults" do
    it "is a single-quoted literal on PostgreSQL and MySQL" do
      {postgres_widgets, mysql_widgets}.each do |widgets|
        widgets.schema.table(:events) do
          primary :id, Int32
          column :at, Time, default: Time.utc(2024, 1, 1)
        end.create_sql.should contain(" DEFAULT '2024-01-01 00:00:00.000' NOT NULL")
      end
    end

    it "is written in UTC, like a bound Time" do
      tokyo = Time::Location.fixed(9 * 3600)
      postgres_widgets.schema.table(:events) do
        primary :id, Int32
        column :at, Time, default: Time.local(2024, 1, 1, 9, 0, 0, location: tokyo)
      end.create_sql.should contain(" DEFAULT '2024-01-01 00:00:00.000' NOT NULL")
    end

    it "is stored as given on SQLite" do
      with_widgets do |schema|
        schema.alter :widgets do
          add_column :at, Time, default: Time.utc(2024, 1, 1)
        end

        schema.exec_query(&.query_one("SELECT at FROM widgets", as: String)).should eq("2024-01-01 00:00:00.000")
      end
    end

    it "keeps each statement whole, whatever its default holds" do
      table = mysql_widgets
      alter = CQL::AlterTable.new(table, table.schema)
      alter.add_column(:status, String, default: "\\';\nDROP TABLE users;\n--", index: true)

      alter.statements(Expression::Generator.new(CQL::Adapter::MySql)).should eq([
        "ALTER TABLE widgets ADD COLUMN status VARCHAR(255) DEFAULT '\\\\'';\nDROP TABLE users;\n--'",
        "CREATE INDEX idx_widgets_status ON widgets (status)",
      ])
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

  describe "#rename_table" do
    it "runs the statements declared before it against the old name" do
      with_widgets do |schema|
        schema.alter :widgets do
          add_column :sku, String, null: true, index: true
          rename_table :gadgets
          add_column :weight, Int32, null: true
        end

        query_all_strings(schema, "SELECT name FROM pragma_table_info('gadgets')").should eq(["id", "name", "sku", "weight"])
        query_all_strings(schema, "SELECT name FROM pragma_index_list('gadgets')").should contain("idx_widgets_sku")
      end
    end

    it "renders each statement under the table name in effect when it was declared" do
      with_widgets do |schema|
        alter_sql(schema.widgets, CQL::Adapter::SQLite) do
          add_column :sku, String, null: true
          create_index :idx_sku, [:sku]
          rename_table :gadgets
          add_column :weight, Int32, null: true
        end.should eq("ALTER TABLE widgets ADD COLUMN sku TEXT;\nCREATE INDEX idx_sku ON widgets (sku);\n" \
                      "ALTER TABLE widgets RENAME TO gadgets;\nALTER TABLE gadgets ADD COLUMN weight INTEGER;\n")
      end

      alter_sql(postgres_widgets, CQL::Adapter::Postgres) do
        foreign_key [:id], references: :owners
        rename_table :gadgets
      end.should eq("ALTER TABLE widgets ADD CONSTRAINT fk_widgets_id FOREIGN KEY (id) REFERENCES owners (id) ON DELETE NO ACTION ON UPDATE NO ACTION;\n" \
                    "ALTER TABLE widgets RENAME TO gadgets;\n")
    end
  end

  describe "statement order" do
    it "renders index, foreign key and column statements on each side of a rename under that side's name" do
      alter_sql(mysql_widgets, CQL::Adapter::MySql) do
        drop_index :idx_widgets_name
        drop_foreign_key :fk_widgets_owner
        rename_table :gadgets
        drop_index :idx_gadgets_name
        drop_column :name
      end.should eq("DROP INDEX idx_widgets_name ON widgets;\nALTER TABLE widgets DROP FOREIGN KEY fk_widgets_owner;\n" \
                    "RENAME TABLE widgets TO gadgets;\nDROP INDEX idx_gadgets_name ON gadgets;\nALTER TABLE gadgets DROP COLUMN name;\n")
    end

    it "changes a column's type under the name it had before a later rename_column" do
      alter_sql(postgres_widgets, CQL::Adapter::Postgres) do
        change_column :name, Int32
        rename_column :name, :title
      end.should eq("ALTER TABLE widgets ALTER COLUMN name TYPE INTEGER;\nALTER TABLE widgets RENAME COLUMN name TO title;\n")
    end
  end

  describe "#rename_column" do
    it "leaves a column added earlier in the block, and its index, under the declared name" do
      with_widgets do |schema|
        schema.alter :widgets do
          add_column :sku, String, null: true, index: true
          rename_column :sku, :code
        end

        query_all_strings(schema, "SELECT name FROM pragma_table_info('widgets')").should eq(["id", "name", "code"])
      end
    end
  end

  describe "#drop_column" do
    it "drops a column the schema does not declare" do
      with_widgets do |schema|
        schema.exec("ALTER TABLE widgets ADD COLUMN legacy TEXT")

        schema.alter :widgets do
          drop_column :legacy
        end

        query_all_strings(schema, "SELECT name FROM pragma_table_info('widgets')").should eq(["id", "name"])
      end
    end

    it "rejects a column name that is not an identifier" do
      expect_raises(ArgumentError, /Invalid column name/) do
        alter_sql(postgres_widgets, CQL::Adapter::Postgres) { drop_column :"name; DROP TABLE widgets" }
      end
    end
  end

  describe "#foreign_key" do
    it "raises CQL::SQLiteUnsupportedFeatureError on SQLite" do
      with_widgets do |schema|
        expect_raises(CQL::SQLiteUnsupportedFeatureError, "adding foreign keys to an existing table") do
          schema.alter :widgets do
            foreign_key [:id], references: :widgets
          end
        end
      end
    end

    it "references the referenced table's primary key when no columns are given, as Table#foreign_key does" do
      widgets = postgres_widgets
      widgets.schema.table(:labels) do
        primary :label_no, Int32
      end

      alter_sql(widgets, CQL::Adapter::Postgres) { foreign_key [:name], references: :labels }
        .should contain("REFERENCES labels (label_no)")
    end
  end
end
