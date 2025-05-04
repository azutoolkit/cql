require "../spec_helper"

describe CQL::Schema do
  db_file = "spec/support/db/test.db"

  after_each do
    File.delete(db_file) if File.exists?(db_file)
  end

  describe "initialization" do
    it "creates a schema with valid name and URI" do
      schema = CQL::Schema.define(:test_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3://#{db_file}") do
        table :users do
          primary :id, Int32
          column :name, String
        end
      end
      schema.name.should eq :test_db
      schema.uri.should eq "sqlite3://#{db_file}"
      schema.adapter.should eq CQL::Adapter::SQLite
      schema.version.should eq "1.0"
    end

    it "raises error for invalid SQLite URI" do
      expect_raises(CQL::Schema::InvalidURIError, "Unsupported database type: invalid") do
        CQL::Schema.define(:test_db, adapter: CQL::Adapter::SQLite, uri: "invalid://test.db") do
          table :users do
            primary :id, Int32
            column :name, String
          end
        end
      end
    end

    it "raises error for invalid PostgreSQL URI without host" do
      expect_raises(DB::ConnectionRefused) do
        CQL::Schema.define(:test_db, adapter: CQL::Adapter::Postgres, uri: "postgresql:///testdb") do
          table :users do
            primary :id, Int32
            column :name, String
          end
        end
      end
    end

    it "raises error for malformed URI" do
      expect_raises(CQL::Schema::InvalidURIError, "Invalid database URI format") do
        CQL::Schema.define(:test_db, adapter: CQL::Adapter::SQLite, uri: "not a uri") do
          table :users do
            primary :id, Int32
            column :name, String
          end
        end
      end
    end
  end

  describe "table operations" do
    it "creates and manages tables" do
      schema = CQL::Schema.define(:test_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3://#{db_file}") do
        table :users do
          primary :id, Int32
          column :name, String
          column :email, String
        end

        table :posts do
          primary :id, Int32
          column :title, String
          column :user_id, Int32
        end
      end

      schema.tables.size.should eq 2
      schema.tables[:users]?.should_not be_nil
      schema.tables[:posts]?.should_not be_nil

      users_table = schema.tables[:users]
      users_table.table_name.should eq :users
      users_table.columns.size.should eq 3

      posts_table = schema.tables[:posts]
      posts_table.table_name.should eq :posts
      posts_table.columns.size.should eq 3
    end

    it "builds schema and creates tables in database" do
      schema = CQL::Schema.define(:test_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3://#{db_file}") do
        table :users do
          primary :id, Int32
          column :name, String
        end
      end

      schema.build

      # Verify table was created
      result = schema.exec_query(&.query_one("SELECT name FROM sqlite_master WHERE type='table' AND name='users'", as: String))
      result.should eq "users"
    end

    it "handles table aliases" do
      schema = CQL::Schema.define(:test_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3://#{db_file}") do
        table :users, as: :u do
          primary :id, Int32
          column :name, String
        end
      end

      table = schema.tables[:users]
      table.as_name.should eq "u"
    end
  end

  describe "query operations" do
    it "executes SQL statements" do
      schema = CQL::Schema.define(:test_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3://#{db_file}") do
        table :users do
          primary :id, Int32
          column :name, String
        end
      end

      schema.build
      schema.exec("INSERT INTO users (name) VALUES ('John')")

      result = schema.exec_query(&.query_one("SELECT name FROM users WHERE id = 1", as: String))
      result.should eq "John"
    end

    it "handles query errors gracefully" do
      schema = CQL::Schema.define(:test_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3://#{db_file}") do
        table :users do
          primary :id, Int32
          column :name, String
        end
      end

      expect_raises(SQLite3::Exception, "no such table: non_existent_table") do
        schema.exec("SELECT * FROM non_existent_table")
      end
    end

    it "creates and executes queries" do
      schema = CQL::Schema.define(:test_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3://#{db_file}") do
        table :users_2 do
          primary :id, Int32
          column :name, String
        end
      end

      schema.build
      schema.exec("INSERT INTO users_2 (name) VALUES ('John')")

      result = schema.query
        .from(:users_2)
        .where(id: 1)
        .first!(as: {id: Int32, name: String})

      result[:id].should eq 1
      result[:name].should eq "John"
    end
  end

  describe "alter table operations" do
    it "alters table structure" do
      schema = CQL::Schema.define(:test_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3://#{db_file}") do
        table :users do
          primary :id, Int32
          column :name, String
        end
      end

      schema.users.drop!
      schema.users.create!

      schema.alter(:users) do
        add_column :email, String
      end

      schema.exec("INSERT INTO users (name, email) VALUES ('John', 'john@example.com')")

      # Verify column was added
      result = schema.exec_query(&.query_one("SELECT email FROM users LIMIT 1", as: String?))
      result.should eq "john@example.com"
    end

    it "raises error when altering non-existent table" do
      schema = CQL::Schema.define(:test_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3://#{db_file}") do
        table :users do
          primary :id, Int32
          column :name, String
        end
      end

      expect_raises(CQL::Schema::Error, "Table 'non_existent' not found") do
        schema.alter(:non_existent) do
          add_column :email, String
        end
      end
    end
  end

  describe "structure dumping" do
    it "dumps schema structure to file" do
      test_schema = CQL::Schema.define(:test_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3://#{db_file}") do
        table :users do
          primary :id, type: Int32, auto_increment: false
          column :name, String
        end
      end

      test_schema.tables.size.should eq 1

      test_schema.dump_structure("test_structure.sql")

      content = File.read("test_structure.sql")
      content.should contain("-- Table: users")
      content.should contain("-- Primary Key: id")
      content.should contain("CREATE TABLE")
      content.should contain("id INTEGER PRIMARY KEY")
      content.should contain("name TEXT NOT NULL")

      File.delete("test_structure.sql")
    end

    it "handles structure dump errors gracefully" do
      invalid_path = "/invalid/path/structure.sql"
      File.delete(invalid_path) if File.exists?(invalid_path)

      schema = CQL::Schema.define(
          :test_db,
          adapter: CQL::Adapter::SQLite,
          uri: "sqlite3://#{db_file}") do
        table :users do
          primary :id, Int32
          column :name, String
        end
      end

      expect_raises(CQL::Schema::Error) do
        schema.dump_structure(invalid_path)
      end
    end
  end
end
