require "../spec_helper"

describe CQL::SchemaDump do
  describe "SQLite schema dumping" do
    it "can dump a SQLite database schema" do
      # Use the existing UserDB test database
      UserDB.build  # Make sure the database exists

      dumper = CQL::SchemaDump.new(CQL::Adapter::SQLite, "sqlite3://spec/support/db/user_db.db")

      # Generate schema content
      schema_content = dumper.generate_schema_content(:TestDB, :test_db)

      # Verify the content contains expected elements
      schema_content.should contain("CQL::Schema.define")
      schema_content.should contain(":test_db")
      schema_content.should contain("CQL::Adapter::SQLite")
      schema_content.should contain("table :users do")
      schema_content.should contain("primary :id, Int32")
      schema_content.should contain("text :name")
      schema_content.should contain("text :email")
      schema_content.should contain("integer :age")
      schema_content.should contain("timestamps")

      dumper.close
    end

    it "can dump schema to file" do
      UserDB.build  # Make sure the database exists

      dumper = CQL::SchemaDump.new(CQL::Adapter::SQLite, "sqlite3://spec/support/db/user_db.db")

      test_file = "spec/support/generated_test_schema.cr"
      dumper.dump_to_file(test_file, :TestSchema, :test_schema)

      # Verify file was created and contains expected content
      File.exists?(test_file).should be_true
      content = File.read(test_file)
      content.should contain("TestSchema = CQL::Schema.define")

      # Clean up
      dumper.close
      File.delete(test_file) if File.exists?(test_file)
    end

    it "handles foreign keys correctly" do
      UserDB.build  # Make sure the database exists

      dumper = CQL::SchemaDump.new(CQL::Adapter::SQLite, "sqlite3://spec/support/db/user_db.db")

      schema_content = dumper.generate_schema_content(:TestDB, :test_db)

      # Check that foreign keys are included
      schema_content.should contain("foreign_key")
      schema_content.should contain("references:")

      dumper.close
    end
  end

    describe "type mapping" do
    it "maps SQLite types correctly through schema generation" do
      UserDB.build  # Make sure the database exists

      dumper = CQL::SchemaDump.new(CQL::Adapter::SQLite, "sqlite3://spec/support/db/user_db.db")

      schema_content = dumper.generate_schema_content(:TestDB, :test_db)

      # Verify that the generated schema contains the correct column methods
      schema_content.should contain("integer") # From INTEGER columns
      schema_content.should contain("text")    # From TEXT columns
      schema_content.should contain("primary :id, Int32") # Primary key still shows type

      dumper.close
    end
  end

  describe "error handling" do
    it "raises error for invalid database connection" do
      expect_raises(CQL::SchemaDump::Error, "Failed to connect to database") do
        CQL::SchemaDump.new(CQL::Adapter::SQLite, "sqlite3://nonexistent/path/database.db")
      end
    end
  end
end
