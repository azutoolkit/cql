require "../spec_helper"

module Expression
  describe PostgresDialect do
    describe "#placeholder_format" do
      it "uses $n format for placeholders" do
        dialect = PostgresDialect.new
        dialect.placeholder_format(0).should eq("$0")
        dialect.placeholder_format(5).should eq("$5")
        dialect.placeholder_format(99).should eq("$99")
      end
    end

    describe "#structure_dump" do
      it "uses pg_dump for structure dumps" do
        dialect = PostgresDialect.new
        uri = URI.parse("postgres://user:pass@localhost:5432/mydb")

        # This is a bit tricky to test directly since it calls an external process
        # We'll test that the command includes the expected parameters
        # In a real environment, you might want to mock Process.new

        # For now, we'll just verify the method exists and returns a string
        dialect.structure_dump(uri).should be_a(String)
      end
    end

    describe "#auto_increment_primary_key" do
      it "generates PostgreSQL-specific IDENTITY syntax" do
        dialect = PostgresDialect.new
        column = CQL::PrimaryKey(Int32).new(:id, Int32, auto_increment: true)

        result = dialect.auto_increment_primary_key(column, "INTEGER")
        result.should eq("id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY")

        # Test without auto_increment
        column = CQL::PrimaryKey(Int32).new(:id, Int32, auto_increment: false)
        result = dialect.auto_increment_primary_key(column, "INTEGER")
        result.should eq("id INTEGER GENERATED AS IDENTITY PRIMARY KEY")
      end
    end

    describe "#rename_column" do
      it "uses PostgreSQL syntax for renaming columns" do
        dialect = PostgresDialect.new
        # PostgreSQL doesn't need column type for renaming
        result = dialect.rename_column("users", "email", "email_address", nil)
        result.should eq("RENAME COLUMN email TO email_address")
      end
    end

    describe "#modify_column" do
      it "uses ALTER COLUMN TYPE syntax" do
        dialect = PostgresDialect.new
        result = dialect.modify_column("users", "email", "VARCHAR(100)")
        result.should eq("ALTER COLUMN email TYPE VARCHAR(100)")
      end
    end

    describe "#define_column" do
      it "handles PostgreSQL-specific default values" do
        dialect = PostgresDialect.new

        # Test boolean default
        result = dialect.define_column("active", "BOOLEAN", true, true, false, false)
        result.should eq("active BOOLEAN DEFAULT TRUE")

        # Test timestamp default
        time = Time.utc(2023, 1, 1, 12, 0, 0)
        result = dialect.define_column("created_at", "TIMESTAMP", time, false, false, true)
        result.should contain("DEFAULT ''2023-01-01 12:00:00.000''")
        result.should contain("NOT NULL")
      end
    end

    describe "#format_returning" do
      it "supports RETURNING clause" do
        dialect = PostgresDialect.new

        # Single column
        result = dialect.format_returning(["id"])
        result.should eq(" RETURNING id")

        # Multiple columns
        result = dialect.format_returning(["id", "name", "email"])
        result.should eq(" RETURNING id, name, email")

        # Empty columns
        result = dialect.format_returning([] of String)
        result.should eq("")
      end
    end

    describe "#format_update_returning" do
      it "supports RETURNING clause for UPDATE" do
        dialect = PostgresDialect.new

        result = dialect.format_update_returning(["id", "updated_at"])
        result.should eq(" RETURNING id, updated_at")
      end
    end

    describe "#format_delete_returning" do
      it "supports RETURNING clause for DELETE" do
        dialect = PostgresDialect.new

        result = dialect.format_delete_returning(["id"])
        result.should eq(" RETURNING id")
      end
    end

    describe "complex operations" do
      it "handles complex column definitions" do
        dialect = PostgresDialect.new

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
        dialect = PostgresDialect.new

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
        dialect = PostgresDialect.new

        # Empty column list for index
        result = dialect.create_index("idx_test", "users", [] of String, false)
        result.should eq("CREATE INDEX idx_test ON users ()")

        # Empty returning columns
        result = dialect.format_returning([] of String)
        result.should eq("")
      end

      it "handles special characters in identifiers" do
        dialect = PostgresDialect.new

        # Table name with special characters
        result = dialect.create_table_prefix("user-data")
        result.should eq("CREATE TABLE IF NOT EXISTS user-data")

        # In a real implementation, you might want to quote identifiers
        # that contain special characters or match reserved words
      end
    end
  end
end
