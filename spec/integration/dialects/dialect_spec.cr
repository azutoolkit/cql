require "../spec_helper"

# Helper method to create dialect instances for testing
def create_dialect(type : Symbol)
  case type
  when :postgres
    Expression::PostgresDialect.new
  when :mysql
    Expression::MySqlDialect.new
  when :sqlite
    Expression::SqliteDialect.new
  else
    raise "Unknown dialect type: #{type}"
  end
end

module Expression
  describe BaseDialect do
    # Test placeholders across dialects
    describe "#placeholder_format" do
      it "formats placeholders according to dialect rules" do
        postgres = create_dialect(:postgres)
        mysql = create_dialect(:mysql)
        sqlite = create_dialect(:sqlite)

        # PostgreSQL uses $n format (1-based)
        postgres.placeholder_format(0).should eq("$0")
        postgres.placeholder_format(1).should eq("$1")
        postgres.placeholder_format(10).should eq("$10")

        # MySQL uses ? for all placeholders
        mysql.placeholder_format(0).should eq("?")
        mysql.placeholder_format(1).should eq("?")
        mysql.placeholder_format(10).should eq("?")

        # SQLite uses ? for all placeholders
        sqlite.placeholder_format(0).should eq("?")
        sqlite.placeholder_format(1).should eq("?")
        sqlite.placeholder_format(10).should eq("?")
      end
    end

    # Test auto-increment primary key syntax
    describe "#auto_increment_primary_key" do
      it "generates correct auto-increment primary key syntax for each dialect" do
        postgres = create_dialect(:postgres)
        mysql = create_dialect(:mysql)
        sqlite = create_dialect(:sqlite)

        # Create a mock column
        column = CQL::PrimaryKey(Int32).new(:id)

        # Test each dialect's implementation
        postgres_result = postgres.auto_increment_primary_key(column, "INTEGER")
        postgres_result.should contain("GENERATED")
        postgres_result.should contain("ALWAYS")
        postgres_result.should contain("AS IDENTITY PRIMARY KEY")

        mysql_result = mysql.auto_increment_primary_key(column, "INTEGER")
        mysql_result.should contain("PRIMARY KEY")
        mysql_result.should contain("AUTO_INCREMENT")

        sqlite_result = sqlite.auto_increment_primary_key(column, "INTEGER")
        sqlite_result.should contain("PRIMARY KEY AUTOINCREMENT")
      end
    end

    # Test table operations
    describe "table operations" do
      it "generates correct table creation syntax" do
        postgres = create_dialect(:postgres)
        mysql = create_dialect(:mysql)
        sqlite = create_dialect(:sqlite)

        # Test create table prefix
        postgres.create_table_prefix("users").should eq("CREATE TABLE IF NOT EXISTS users")
        mysql.create_table_prefix("users").should eq("CREATE TABLE IF NOT EXISTS users")
        sqlite.create_table_prefix("users").should eq("CREATE TABLE IF NOT EXISTS users")

        # Test drop table
        postgres.drop_table("users").should eq("DROP TABLE IF EXISTS users")
        mysql.drop_table("users").should eq("DROP TABLE IF EXISTS users")
        sqlite.drop_table("users").should eq("DROP TABLE IF EXISTS users")

        # Test truncate table
        postgres.truncate_table("users").should eq("TRUNCATE TABLE users")
        mysql.truncate_table("users").should eq("TRUNCATE TABLE users")
        sqlite.truncate_table("users").should eq("DELETE FROM users") # SQLite uses DELETE FROM instead
      end

      it "generates correct alter table syntax" do
        postgres = create_dialect(:postgres)
        mysql = create_dialect(:mysql)
        sqlite = create_dialect(:sqlite)

        # Test alter table
        postgres.alter_table("users", "ADD COLUMN email VARCHAR(255)").should eq("ALTER TABLE users ADD COLUMN email VARCHAR(255)")
        mysql.alter_table("users", "ADD COLUMN email VARCHAR(255)").should eq("ALTER TABLE users ADD COLUMN email VARCHAR(255)")
        sqlite.alter_table("users", "ADD COLUMN email VARCHAR(255)").should eq("ALTER TABLE users ADD COLUMN email VARCHAR(255)")

        # Test rename table
        postgres.rename_table("users", "people").should eq("ALTER TABLE users RENAME TO people")
        mysql.rename_table("users", "people").should eq("RENAME TABLE users TO people")
        sqlite.rename_table("users", "people").should eq("ALTER TABLE users RENAME TO people")
      end
    end

    # Test column operations
    describe "column operations" do
      it "generates correct column definition syntax" do
        postgres = create_dialect(:postgres)
        mysql = create_dialect(:mysql)
        sqlite = create_dialect(:sqlite)

        # Test basic column definition
        postgres_col = postgres.define_column("name", "VARCHAR(255)", nil, true, false, false)
        postgres_col.should eq("name VARCHAR(255)")

        mysql_col = mysql.define_column("name", "VARCHAR(255)", nil, true, false, false)
        mysql_col.should eq("name VARCHAR(255)")

        sqlite_col = sqlite.define_column("name", "VARCHAR(255)", nil, true, false, false)
        sqlite_col.should eq("name VARCHAR(255)")

        # Test not null constraint
        postgres_col = postgres.define_column("name", "VARCHAR(255)", nil, false, false, false)
        postgres_col.should eq("name VARCHAR(255) NOT NULL")

        # Test unique constraint
        postgres_col = postgres.define_column("email", "VARCHAR(255)", nil, true, true, false)
        postgres_col.should eq("email VARCHAR(255) UNIQUE")

        # Test default value (string)
        postgres_col = postgres.define_column("status", "VARCHAR(50)", "active", true, false, false)
        postgres_col.should eq("status VARCHAR(50) DEFAULT 'active'")

        # Test default value (boolean)
        postgres_col = postgres.define_column("active", "BOOLEAN", true, true, false, false)
        postgres_col.should contain("DEFAULT TRUE")
        mysql_col = mysql.define_column("active", "BOOLEAN", true, true, false, false)
        mysql_col.should contain("DEFAULT TRUE")
        sqlite_col = sqlite.define_column("active", "BOOLEAN", true, true, false, false)
        sqlite_col.should contain("DEFAULT 1") # SQLite uses 1/0 for booleans
      end

      it "generates correct add column syntax" do
        postgres = create_dialect(:postgres)
        mysql = create_dialect(:mysql)
        sqlite = create_dialect(:sqlite)

        # Test add column
        postgres_add = postgres.add_column("email", "VARCHAR(255)", false, false, true)
        postgres_add.should eq("ADD COLUMN email VARCHAR(255) NOT NULL UNIQUE")

        mysql_add = mysql.add_column("email", "VARCHAR(255)", false, false, true)
        mysql_add.should eq("ADD COLUMN email VARCHAR(255) NOT NULL UNIQUE")

        # SQLite doesn't support adding a PRIMARY KEY column
        expect_raises(CQL::SQLiteUnsupportedFeatureError) do
          sqlite.add_column("id", "INTEGER", true, false, false)
        end
      end

      it "generates correct drop column syntax" do
        postgres = create_dialect(:postgres)
        mysql = create_dialect(:mysql)
        sqlite = create_dialect(:sqlite)

        # Test drop column
        postgres.drop_column("email").should eq("DROP COLUMN email")
        mysql.drop_column("email").should eq("DROP COLUMN email")

        # SQLite has a warning comment for compatibility
        sqlite.drop_column("email").should contain("DROP COLUMN email")
        sqlite.drop_column("email").should contain("Warning")
      end

      it "handles column modification correctly" do
        postgres = create_dialect(:postgres)
        mysql = create_dialect(:mysql)
        sqlite = create_dialect(:sqlite)

        # Test modify column
        postgres.modify_column("users", "email", "VARCHAR(100)").should eq("ALTER COLUMN email TYPE VARCHAR(100)")
        mysql.modify_column("users", "email", "VARCHAR(100)").should eq("MODIFY COLUMN email VARCHAR(100)")

        # SQLite doesn't support direct column type modification
        expect_raises(CQL::SQLiteUnsupportedFeatureError) do
          sqlite.modify_column("users", "email", "VARCHAR(100)")
        end
      end

      it "handles column renaming correctly" do
        postgres = create_dialect(:postgres)
        mysql = create_dialect(:mysql)
        sqlite = create_dialect(:sqlite)

        # Test rename column
        postgres.rename_column("users", "email", "email_address", nil).should eq("RENAME COLUMN email TO email_address")
        mysql.rename_column("users", "email", "email_address", "VARCHAR(255)").should eq("CHANGE email email_address VARCHAR(255)")
        sqlite.rename_column("users", "email", "email_address", nil).should eq("RENAME COLUMN email TO email_address")
      end
    end

    # Test index operations
    describe "index operations" do
      it "generates correct create index syntax" do
        postgres = create_dialect(:postgres)
        create_dialect(:mysql)
        create_dialect(:sqlite)

        # Test create index
        postgres_idx = postgres.create_index("idx_users_email", "users", ["email"], false)
        postgres_idx.should eq("CREATE INDEX idx_users_email ON users (email)")

        # Test create unique index
        postgres_idx = postgres.create_index("idx_users_email", "users", ["email"], true)
        postgres_idx.should eq("CREATE UNIQUE INDEX idx_users_email ON users (email)")

        # Test multi-column index
        postgres_idx = postgres.create_index("idx_users_name_email", "users", ["name", "email"], false)
        postgres_idx.should eq("CREATE INDEX idx_users_name_email ON users (name, email)")
      end

      it "generates correct drop index syntax" do
        postgres = create_dialect(:postgres)
        mysql = create_dialect(:mysql)
        sqlite = create_dialect(:sqlite)

        # Test drop index
        postgres.drop_index("idx_users_email", "users").should eq("DROP INDEX IF EXISTS idx_users_email")
        mysql.drop_index("idx_users_email", "users").should eq("DROP INDEX idx_users_email ON users")
        sqlite.drop_index("idx_users_email", "users").should eq("DROP INDEX IF EXISTS idx_users_email")
      end
    end

    # Test foreign key operations
    describe "foreign key operations" do
      it "generates correct add foreign key syntax" do
        postgres = create_dialect(:postgres)
        mysql = create_dialect(:mysql)
        sqlite = create_dialect(:sqlite)

        # Test add foreign key
        fk_postgres = postgres.add_foreign_key(
          "fk_posts_user_id", "posts", ["user_id"],
          "users", ["id"], "CASCADE", "CASCADE"
        )
        fk_postgres.should eq("ADD CONSTRAINT fk_posts_user_id FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE")

        fk_mysql = mysql.add_foreign_key(
          "fk_posts_user_id", "posts", ["user_id"],
          "users", ["id"], "CASCADE", "CASCADE"
        )
        fk_mysql.should eq("ADD CONSTRAINT fk_posts_user_id FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE")

        # SQLite doesn't support adding foreign keys to existing tables
        expect_raises(CQL::SQLiteUnsupportedFeatureError) do
          sqlite.add_foreign_key(
            "fk_posts_user_id", "posts", ["user_id"],
            "users", ["id"], "CASCADE", "CASCADE"
          )
        end
      end

      it "generates correct drop foreign key syntax" do
        postgres = create_dialect(:postgres)
        mysql = create_dialect(:mysql)
        sqlite = create_dialect(:sqlite)

        # Test drop foreign key
        postgres.drop_foreign_key("posts", "fk_posts_user_id").should eq("DROP CONSTRAINT fk_posts_user_id")
        mysql.drop_foreign_key("posts", "fk_posts_user_id").should eq("DROP FOREIGN KEY fk_posts_user_id")

        # SQLite doesn't support dropping foreign keys
        expect_raises(CQL::SQLiteUnsupportedFeatureError) do
          sqlite.drop_foreign_key("posts", "fk_posts_user_id")
        end
      end
    end

    # Test query components
    describe "query components" do
      it "formats LIMIT and OFFSET correctly" do
        postgres = create_dialect(:postgres)
        mysql = create_dialect(:mysql)
        sqlite = create_dialect(:sqlite)

        # Test limit only
        postgres.format_limit_offset(10, nil).should eq(" LIMIT 10")
        mysql.format_limit_offset(10, nil).should eq(" LIMIT 10")
        sqlite.format_limit_offset(10, nil).should eq(" LIMIT 10")

        # Test limit and offset
        postgres.format_limit_offset(10, 20).should eq(" LIMIT 10 OFFSET 20")
        mysql.format_limit_offset(10, 20).should eq(" LIMIT 10 OFFSET 20")
        sqlite.format_limit_offset(10, 20).should eq(" LIMIT 10 OFFSET 20")
      end

      it "formats INSERT VALUES correctly" do
        postgres = create_dialect(:postgres)
        mysql = create_dialect(:mysql)
        sqlite = create_dialect(:sqlite)

        values = [[1, "John"], [2, "Jane"]]
        placeholders = ["$1", "$2"] # For PostgreSQL

        # Test PostgreSQL
        postgres_values = postgres.format_insert_values(values, placeholders)
        postgres_values.should eq(" VALUES ($1, $2), ($1, $2)")

        # For MySQL and SQLite, we'd use ? placeholders
        placeholders = ["?", "?"]

        mysql_values = mysql.format_insert_values(values, placeholders)
        mysql_values.should eq(" VALUES (?, ?), (?, ?)")

        sqlite_values = sqlite.format_insert_values(values, placeholders)
        sqlite_values.should eq(" VALUES (?, ?), (?, ?)")
      end

      it "handles RETURNING clause correctly" do
        postgres = create_dialect(:postgres)
        mysql = create_dialect(:mysql)
        sqlite = create_dialect(:sqlite)

        # Test RETURNING clause
        postgres.format_returning(["id", "name"]).should eq(" RETURNING id, name")
        mysql.format_returning(["id", "name"]).should eq("") # MySQL doesn't support RETURNING

        # SQLite raises an error if RETURNING is used
        expect_raises(CQL::SQLiteUnsupportedFeatureError) do
          sqlite.format_returning(["id", "name"])
        end

        # Empty columns should return empty string for all dialects
        postgres.format_returning([] of String).should eq("")
        mysql.format_returning([] of String).should eq("")
        sqlite.format_returning([] of String).should eq("")
      end

      it "handles UPDATE RETURNING clause correctly" do
        postgres = create_dialect(:postgres)
        mysql = create_dialect(:mysql)
        sqlite = create_dialect(:sqlite)

        # Test UPDATE RETURNING clause
        postgres.format_update_returning(["id", "name"]).should eq(" RETURNING id, name")
        mysql.format_update_returning(["id", "name"]).should eq("") # MySQL doesn't support RETURNING

        # SQLite raises an error if RETURNING is used
        expect_raises(CQL::SQLiteUnsupportedFeatureError) do
          sqlite.format_update_returning(["id", "name"])
        end
      end

      it "handles DELETE RETURNING clause correctly" do
        postgres = create_dialect(:postgres)
        mysql = create_dialect(:mysql)
        sqlite = create_dialect(:sqlite)

        # Test DELETE RETURNING clause
        postgres.format_delete_returning(["id", "name"]).should eq(" RETURNING id, name")
        mysql.format_delete_returning(["id", "name"]).should eq("") # MySQL doesn't support RETURNING

        # SQLite raises an error if RETURNING is used
        expect_raises(CQL::SQLiteUnsupportedFeatureError) do
          sqlite.format_delete_returning(["id", "name"])
        end
      end
    end

    # Test conditions and operators
    describe "conditions and operators" do
      it "formats LIKE conditions correctly" do
        postgres = create_dialect(:postgres)
        mysql = create_dialect(:mysql)
        sqlite = create_dialect(:sqlite)

        postgres.format_like("name", "$1").should eq("name LIKE $1")
        mysql.format_like("name", "?").should eq("name LIKE ?")
        sqlite.format_like("name", "?").should eq("name LIKE ?")

        postgres.format_not_like("name", "$1").should eq("name NOT LIKE $1")
        mysql.format_not_like("name", "?").should eq("name NOT LIKE ?")
        sqlite.format_not_like("name", "?").should eq("name NOT LIKE ?")
      end

      it "formats NULL conditions correctly" do
        postgres = create_dialect(:postgres)
        mysql = create_dialect(:mysql)
        sqlite = create_dialect(:sqlite)

        postgres.format_is_null("email").should eq("email IS NULL")
        mysql.format_is_null("email").should eq("email IS NULL")
        sqlite.format_is_null("email").should eq("email IS NULL")

        postgres.format_is_not_null("email").should eq("email IS NOT NULL")
        mysql.format_is_not_null("email").should eq("email IS NOT NULL")
        sqlite.format_is_not_null("email").should eq("email IS NOT NULL")
      end
    end

    # Test aggregate functions
    describe "aggregate functions" do
      it "formats aggregate functions correctly" do
        postgres = create_dialect(:postgres)
        mysql = create_dialect(:mysql)
        sqlite = create_dialect(:sqlite)

        # Test COUNT
        postgres.format_count("id").should eq("COUNT(id)")
        mysql.format_count("id").should eq("COUNT(id)")
        sqlite.format_count("id").should eq("COUNT(id)")

        # Test MAX
        postgres.format_max("price").should eq("MAX(price)")
        mysql.format_max("price").should eq("MAX(price)")
        sqlite.format_max("price").should eq("MAX(price)")

        # Test MIN
        postgres.format_min("price").should eq("MIN(price)")
        mysql.format_min("price").should eq("MIN(price)")
        sqlite.format_min("price").should eq("MIN(price)")

        # Test AVG
        postgres.format_avg("price").should eq("AVG(price)")
        mysql.format_avg("price").should eq("AVG(price)")
        sqlite.format_avg("price").should eq("AVG(price)")

        # Test SUM
        postgres.format_sum("price").should eq("SUM(price)")
        mysql.format_sum("price").should eq("SUM(price)")
        sqlite.format_sum("price").should eq("SUM(price)")
      end
    end
  end
end
