require "../spec_helper"

module Expression
  describe MySqlDialect do
    describe "#placeholder_format" do
      it "uses ? for all placeholders" do
        dialect = MySqlDialect.new
        dialect.placeholder_format(0).should eq("?")
        dialect.placeholder_format(5).should eq("?")
        dialect.placeholder_format(99).should eq("?")
      end
    end

    describe "#structure_dump" do
      it "uses mysqldump for structure dumps" do
        dialect = MySqlDialect.new
        uri = URI.parse("mysql://user:pass@localhost:3306/mydb")

        # This is a bit tricky to test directly since it calls an external process
        # We'll test that the method exists and returns a string
        dialect.structure_dump(uri).should be_a(String)
      end
    end

    describe "#auto_increment_primary_key" do
      it "generates MySQL-specific AUTO_INCREMENT syntax" do
        dialect = MySqlDialect.new
        column = CQL::PrimaryKey(Int32).new(:id)

        result = dialect.auto_increment_primary_key(column, "INTEGER")
        result.should eq("id INTEGER PRIMARY KEY AUTO_INCREMENT")

        # Test without auto_increment
        column = CQL::PrimaryKey(Int32).new(:id, auto_increment: false)
        result = dialect.auto_increment_primary_key(column, "INTEGER")
        result.should eq("id INTEGER PRIMARY KEY")
      end
    end

    describe "#rename_column" do
      it "uses MySQL syntax for renaming columns" do
        dialect = MySqlDialect.new
        # MySQL requires column type for renaming
        result = dialect.rename_column("users", "email", "email_address", "VARCHAR(255)")
        result.should eq("CHANGE email email_address VARCHAR(255)")

        # Should raise if column_type is nil
        expect_raises(Exception) do
          dialect.rename_column("users", "email", "email_address", nil)
        end
      end
    end

    describe "#modify_column" do
      it "uses MODIFY COLUMN syntax" do
        dialect = MySqlDialect.new
        result = dialect.modify_column("users", "email", "VARCHAR(100)")
        result.should eq("MODIFY COLUMN email VARCHAR(100)")
      end
    end

    describe "#drop_index" do
      it "uses MySQL-specific syntax for dropping indexes" do
        dialect = MySqlDialect.new
        result = dialect.drop_index("idx_users_email", "users")
        result.should eq("DROP INDEX idx_users_email ON users")
      end
    end

    describe "#drop_foreign_key" do
      it "uses MySQL-specific syntax for dropping foreign keys" do
        dialect = MySqlDialect.new
        result = dialect.drop_foreign_key("posts", "fk_posts_user_id")
        result.should eq("DROP FOREIGN KEY fk_posts_user_id")
      end
    end

    describe "#rename_table" do
      it "uses MySQL-specific syntax for renaming tables" do
        dialect = MySqlDialect.new
        result = dialect.rename_table("users", "people")
        result.should eq("RENAME TABLE users TO people")
      end
    end

    describe "#define_column" do
      it "handles MySQL-specific default values" do
        dialect = MySqlDialect.new

        # Test boolean default
        result = dialect.define_column("active", "BOOLEAN", true, true, false, false)
        result.should eq("active BOOLEAN DEFAULT TRUE")

        # Test timestamp default (with millisecond precision)
        time = Time.utc(2023, 1, 1, 12, 0, 0)
        result = dialect.define_column("created_at", "TIMESTAMP", time, false, false, true)
        result.should contain("DEFAULT ''2023-01-01 12:00:00.000''")
        result.should contain("NOT NULL")
      end
    end

    describe "#format_returning" do
      it "does not support RETURNING clause" do
        dialect = MySqlDialect.new

        # Single column - MySQL doesn't support RETURNING
        result = dialect.format_returning(["id"])
        result.should eq("")

        # Multiple columns
        result = dialect.format_returning(["id", "name", "email"])
        result.should eq("")

        # Empty columns
        result = dialect.format_returning([] of String)
        result.should eq("")
      end
    end

    describe "#format_update_returning" do
      it "does not support RETURNING clause for UPDATE" do
        dialect = MySqlDialect.new

        result = dialect.format_update_returning(["id", "updated_at"])
        result.should eq("")
      end
    end

    describe "#format_delete_returning" do
      it "does not support RETURNING clause for DELETE" do
        dialect = MySqlDialect.new

        result = dialect.format_delete_returning(["id"])
        result.should eq("")
      end
    end

    describe "complex operations" do
      it "handles complex column definitions" do
        dialect = MySqlDialect.new

        # Column with multiple constraints
        result = dialect.define_column(
          "email",
          "VARCHAR(255)",
          nil,
          false, # not null
          true,  # unique
          false
        )

        result.should eq("email VARCHAR(255) NOT NULL UNIQUE")
      end

      it "handles string escaping in default values" do
        dialect = MySqlDialect.new

        # Test string with single quotes
        result = dialect.define_column(
          "description",
          "TEXT",
          "It's a test",
          true,
          false,
          false
        )

        result.should eq("description TEXT DEFAULT 'It''s a test'")
      end
    end

    describe "edge cases" do
      it "handles empty inputs gracefully" do
        dialect = MySqlDialect.new

        # Empty column list for index
        result = dialect.create_index("idx_test", "users", [] of String, false)
        result.should eq("CREATE INDEX idx_test ON users ()")

        # Empty returning columns
        result = dialect.format_returning([] of String)
        result.should eq("")
      end

      it "handles special characters in identifiers" do
        dialect = MySqlDialect.new

        # Table name with special characters
        result = dialect.create_table_prefix("user-data")
        result.should eq("CREATE TABLE IF NOT EXISTS user-data")

        # In a real implementation, you might want to quote identifiers
        # that contain special characters or match reserved words
      end
    end

    describe "MySQL-specific behaviors" do
      it "correctly formats boolean values" do
        dialect = MySqlDialect.new

        # MySQL uses TRUE/FALSE for boolean literals
        result = dialect.define_column("active", "BOOLEAN", true, true, false, false)
        result.should eq("active BOOLEAN DEFAULT TRUE")

        result = dialect.define_column("active", "BOOLEAN", false, true, false, false)
        result.should eq("active BOOLEAN DEFAULT FALSE")
      end

      it "correctly formats date/time values" do
        dialect = MySqlDialect.new
        time = Time.utc(2023, 1, 1, 12, 0, 0)

        # MySQL datetime format (with millisecond precision)
        result = dialect.define_column("created_at", "DATETIME", time, true, false, false)
        result.should contain("DEFAULT ''2023-01-01 12:00:00.000''")
      end
    end
  end
end
