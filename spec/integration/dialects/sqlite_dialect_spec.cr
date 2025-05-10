require "../spec_helper"

module Expression
  describe SqliteDialect do
    describe "#placeholder_format" do
      it "uses ? for all placeholders" do
        dialect = SqliteDialect.new
        dialect.placeholder_format(0).should eq("?")
        dialect.placeholder_format(5).should eq("?")
        dialect.placeholder_format(99).should eq("?")
      end
    end

    describe "#structure_dump" do
      it "returns empty string for structure dumps" do
        dialect = SqliteDialect.new
        uri = URI.parse("sqlite://./test.db")

        # SQLite doesn't have a built-in structure dump command
        dialect.structure_dump(uri).should eq("")
      end
    end

    describe "#auto_increment_primary_key" do
      it "generates SQLite-specific AUTOINCREMENT syntax for INTEGER primary keys" do
        dialect = SqliteDialect.new
        column = CQL::PrimaryKey(Int32).new(:id, Int32, auto_increment: true)

        result = dialect.auto_increment_primary_key(column, "INTEGER")
        result.should eq("id INTEGER PRIMARY KEY AUTOINCREMENT")

        # Test with non-INTEGER type (doesn't support AUTOINCREMENT)
        column = CQL::Column.new(:id, String)
        result = dialect.auto_increment_primary_key(column, "TEXT")
        result.should eq("id TEXT PRIMARY KEY")
      end
    end

    describe "#rename_column" do
      it "uses SQLite syntax for renaming columns" do
        dialect = SqliteDialect.new
        result = dialect.rename_column("users", "email", "email_address", nil)
        result.should eq("RENAME COLUMN email TO email_address")
      end
    end

    describe "#modify_column" do
      it "raises an error for modifying column types" do
        dialect = SqliteDialect.new

        # SQLite doesn't support ALTER COLUMN directly
        expect_raises(CQL::SQLiteUnsupportedFeatureError) do
          dialect.modify_column("users", "email", "VARCHAR(100)")
        end
      end
    end

    describe "#drop_index" do
      it "uses SQLite syntax for dropping indexes" do
        dialect = SqliteDialect.new
        result = dialect.drop_index("idx_users_email", "users")
        result.should eq("DROP INDEX IF EXISTS idx_users_email")
      end
    end

    describe "#drop_foreign_key" do
      it "raises an error for dropping foreign keys" do
        dialect = SqliteDialect.new

        # SQLite doesn't support dropping foreign keys directly
        expect_raises(CQL::SQLiteUnsupportedFeatureError) do
          dialect.drop_foreign_key("posts", "fk_posts_user_id")
        end
      end
    end

    describe "#rename_table" do
      it "uses SQLite syntax for renaming tables" do
        dialect = SqliteDialect.new
        result = dialect.rename_table("users", "people")
        result.should eq("ALTER TABLE users RENAME TO people")
      end
    end

    describe "#truncate_table" do
      it "uses DELETE FROM instead of TRUNCATE" do
        dialect = SqliteDialect.new
        result = dialect.truncate_table("users")
        result.should eq("DELETE FROM users")
      end
    end

    describe "#add_column" do
      it "supports adding columns with constraints" do
        dialect = SqliteDialect.new

        # Add a regular column
        result = dialect.add_column("email", "VARCHAR(255)", false, false, true)
        result.should eq("ADD COLUMN email VARCHAR(255) NOT NULL UNIQUE")

        # SQLite doesn't support adding PRIMARY KEY columns
        expect_raises(CQL::SQLiteUnsupportedFeatureError) do
          dialect.add_column("id", "INTEGER", true, false, false)
        end
      end
    end

    describe "#drop_column" do
      it "includes a warning comment for SQLite version compatibility" do
        dialect = SqliteDialect.new
        result = dialect.drop_column("email")
        result.should contain("DROP COLUMN email")
        result.should contain("Warning")
        result.should contain("SQLite 3.35.0+")
      end
    end

    describe "#define_column" do
      it "handles SQLite-specific default values" do
        dialect = SqliteDialect.new

        # Test boolean default (SQLite uses 1/0)
        result = dialect.define_column("active", "BOOLEAN", true, true, false, false)
        result.should eq("active BOOLEAN DEFAULT 1")

        result = dialect.define_column("active", "BOOLEAN", false, true, false, false)
        result.should eq("active BOOLEAN DEFAULT 0")

        # Test timestamp default
        time = Time.utc(2023, 1, 1, 12, 0, 0)
        result = dialect.define_column("created_at", "TIMESTAMP", time, false, false, true)
        result.should contain("DEFAULT ''2023-01-01 12:00:00.000''")
        result.should contain("NOT NULL")
      end
    end

    describe "#add_foreign_key" do
      it "raises an error for adding foreign keys to existing tables" do
        dialect = SqliteDialect.new

        expect_raises(CQL::SQLiteUnsupportedFeatureError) do
          dialect.add_foreign_key(
            "fk_posts_user_id", "posts", ["user_id"],
            "users", ["id"], "CASCADE", "CASCADE"
          )
        end
      end
    end

    describe "#format_returning" do
      it "raises an error when RETURNING is used with non-empty columns" do
        dialect = SqliteDialect.new

        # Empty columns should not raise
        result = dialect.format_returning([] of String)
        result.should eq("")

        # Non-empty columns should raise
        expect_raises(CQL::SQLiteUnsupportedFeatureError) do
          dialect.format_returning(["id"])
        end

        expect_raises(CQL::SQLiteUnsupportedFeatureError) do
          dialect.format_returning(["id", "name"])
        end
      end
    end

    describe "#format_update_returning" do
      it "raises an error when RETURNING is used with non-empty columns" do
        dialect = SqliteDialect.new

        # Empty columns should not raise
        result = dialect.format_update_returning([] of String)
        result.should eq("")

        # Non-empty columns should raise
        expect_raises(CQL::SQLiteUnsupportedFeatureError) do
          dialect.format_update_returning(["id"])
        end
      end
    end

    describe "#format_delete_returning" do
      it "raises an error when RETURNING is used with non-empty columns" do
        dialect = SqliteDialect.new

        # Empty columns should not raise
        result = dialect.format_delete_returning([] of String)
        result.should eq("")

        # Non-empty columns should raise
        expect_raises(CQL::SQLiteUnsupportedFeatureError) do
          dialect.format_delete_returning(["id"])
        end
      end
    end

    describe "error handling" do
      it "raises SQLiteUnsupportedFeatureError for modify_column" do
        dialect = SqliteDialect.new

        expect_raises(CQL::SQLiteUnsupportedFeatureError) do
          dialect.modify_column("users", "email", "VARCHAR(100)")
        end
      end

      it "includes helpful information in modify_column error" do
        dialect = SqliteDialect.new

        begin
          dialect.modify_column("users", "email", "VARCHAR(100)")
          fail "Expected to raise SQLiteUnsupportedFeatureError"
        rescue ex : CQL::SQLiteUnsupportedFeatureError
          ex.dialect.should eq("SQLite")
          ex.feature.should eq("ALTER COLUMN syntax")
          ex.workaround.should_not be_nil
        end
      end

      it "raises SQLiteUnsupportedFeatureError for add_foreign_key" do
        dialect = SqliteDialect.new

        expect_raises(CQL::SQLiteUnsupportedFeatureError) do
          dialect.add_foreign_key(
            "fk_posts_user_id", "posts", ["user_id"],
            "users", ["id"], "CASCADE", "CASCADE"
          )
        end
      end

      it "includes helpful information in add_foreign_key error" do
        dialect = SqliteDialect.new

        begin
          dialect.add_foreign_key(
            "fk_posts_user_id", "posts", ["user_id"],
            "users", ["id"], "CASCADE", "CASCADE"
          )
          fail "Expected to raise SQLiteUnsupportedFeatureError"
        rescue ex : CQL::SQLiteUnsupportedFeatureError
          ex.dialect.should eq("SQLite")
          ex.feature.should eq("adding foreign keys to an existing table")
          ex.workaround.should_not be_nil
        end
      end
    end

    describe "SQLite-specific behaviors" do
      it "correctly formats boolean values as 1/0" do
        dialect = SqliteDialect.new

        # SQLite uses 1/0 for boolean literals
        result = dialect.define_column("active", "BOOLEAN", true, true, false, false)
        result.should eq("active BOOLEAN DEFAULT 1")

        result = dialect.define_column("active", "BOOLEAN", false, true, false, false)
        result.should eq("active BOOLEAN DEFAULT 0")
      end

      it "correctly formats date/time values" do
        dialect = SqliteDialect.new
        time = Time.utc(2023, 1, 1, 12, 0, 0)

        # SQLite datetime format (ISO8601)
        result = dialect.define_column("created_at", "TIMESTAMP", time, true, false, false)
        result.should contain("DEFAULT ''2023-01-01 12:00:00.000''")
      end
    end
  end
end
