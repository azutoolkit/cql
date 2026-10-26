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

      it "formats boundary and large indexes as $n" do
        dialect = PostgresDialect.new
        {-1, 0, 1, 9, 1023, 5000}.each do |index|
          dialect.placeholder_format(index).should eq("$#{index}")
        end
      end

      it "numbers more than ten bound parameters $1..$12 in order" do
        generator = Generator.new(CQL::Adapter::Postgres)
        values = (1..12).to_a
        sql, params = Northwind.query.from(:customers).select(:name).where { customers.id.in(values) }.to_sql(generator)

        sql.should end_with("WHERE customers.id IN (#{(1..12).map { |index| "$#{index}" }.join(", ")})")
        params.should eq(values.map { |value| value.as(DB::Any) })
      end
    end

    describe "#max_bind_params" do
      it "allows 32767 bound parameters, the most every driver accepts" do
        CQL::Adapter::Postgres.dialect.max_bind_params.should eq(32767)
      end
    end

    describe "#structure_dump_command" do
      it "runs pg_dump on the URI's host, port, user and database, with the password only in PGPASSWORD" do
        PostgresDialect.new.structure_dump_command(URI.parse("postgres://app%40corp:p%40ss@db.internal:6543/my%20shop")) do |command|
          command.command.should eq("pg_dump")
          command.args.should eq([
            "--schema-only", "--no-comments", "--no-password",
            "--host=db.internal", "--port=6543", "--username=app@corp", "--dbname=my shop",
          ])
          command.env.should eq({"PGPASSWORD" => "p@ss"})
        end
      end

      it "leaves out what the URI does not name" do
        PostgresDialect.new.structure_dump_command(URI.parse("postgres://localhost/shop")) do |command|
          command.args.should eq(["--schema-only", "--no-comments", "--no-password", "--host=localhost", "--dbname=shop"])
          command.env.should be_empty
        end
      end

      it "keeps the URI's sslmode in PGSSLMODE, so the dump is not less secure than the connection" do
        PostgresDialect.new.structure_dump_command(URI.parse("postgres://app:pw@db.internal/shop?sslmode=verify-full&pool_size=5")) do |command|
          command.env.should eq({"PGPASSWORD" => "pw", "PGSSLMODE" => "verify-full"})
        end
      end

      it "does not show the password when inspected" do
        command = StructureDumpCommand.new("pg_dump", ["--dbname=shop"], {"PGPASSWORD" => "s3cret"})

        command.inspect.should_not contain("s3cret")
        command.to_s.should_not contain("s3cret")
        command.pretty_inspect.should_not contain("s3cret")
        command.inspect.should contain("PGPASSWORD")
      end
    end

    describe "#structure_dump" do
      uri = URI.parse("postgres://app:p%40ss@db.internal:6543/shop")

      it "returns what pg_dump printed" do
        FakeTools.with_tool("pg_dump", "echo 'CREATE TABLE users ();'") do
          PostgresDialect.new.structure_dump(uri).should eq("CREATE TABLE users ();\n")
        end
      end

      it "gives pg_dump the decoded password in PGPASSWORD" do
        FakeTools.with_tool("pg_dump", %(printf '%s' "$PGPASSWORD")) do
          PostgresDialect.new.structure_dump(uri).should eq("p@ss")
        end
      end

      it "reads a dump larger than a pipe buffer" do
        FakeTools.with_tool("pg_dump", "yes 'CREATE TABLE users ();' | head -c 200000") do
          PostgresDialect.new.structure_dump(uri).size.should eq(200_000)
        end
      end

      it "raises CQL::Error with pg_dump's stderr when it fails" do
        FakeTools.with_tool("pg_dump", "echo 'pg_dump: error: connection refused' >&2; exit 1") do
          expect_raises(CQL::Error, "pg_dump failed (exit code 1): pg_dump: error: connection refused") do
            PostgresDialect.new.structure_dump(uri)
          end
        end
      end

      it "names the signal that killed pg_dump" do
        FakeTools.with_tool("pg_dump", "kill -KILL $$") do
          expect_raises(CQL::Error, "pg_dump failed (signal KILL): ") { PostgresDialect.new.structure_dump(uri) }
        end
      end

      it "passes only options the installed pg_dump accepts, so it gets as far as connecting" do
        pending!("pg_dump is not installed") unless Process.find_executable("pg_dump")
        error = expect_raises(CQL::Error) { PostgresDialect.new.structure_dump(URI.parse("postgres://app@127.0.0.1:1/shop")) }

        error.message.to_s.should_not contain("unrecognized option")
        error.message.to_s.should contain("127.0.0.1")
      end

      it "raises CQL::Error when pg_dump is not installed" do
        FakeTools.with_path("/nonexistent") do
          expect_raises(CQL::Error, /pg_dump could not be started/) { PostgresDialect.new.structure_dump(uri) }
        end
      end
    end

    describe "#auto_increment_primary_key" do
      it "generates PostgreSQL-specific IDENTITY syntax" do
        dialect = PostgresDialect.new
        column = CQL::PrimaryKey(Int32).new(:id, auto_increment: true)

        result = dialect.auto_increment_primary_key(column, "INTEGER")
        result.should eq("id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY")

        # Test without auto_increment (no IDENTITY generation)
        column = CQL::PrimaryKey(Int32).new(:id, auto_increment: false)
        result = dialect.auto_increment_primary_key(column, "INTEGER")
        result.should eq("id INTEGER PRIMARY KEY")
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
