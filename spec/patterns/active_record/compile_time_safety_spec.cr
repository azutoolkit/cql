require "../../spec_helper"

describe "CQL compile-time safety" do
  it "raises a clear error for unsupported validation predicates" do
    success, _output, error = Snippets.compile <<-CRYSTAL
      require "./src/cql"

      class BrokenValidation
        include CQL::ActiveRecord::Validations

        property name : String?

        validate :name, typo: true
      end
      CRYSTAL

    success.should be_false
    error.should contain("CQL validation error")
    error.should contain("unsupported predicate `typo`")
  end

  it "raises a clear error for malformed belongs_to declarations" do
    success, _output, error = Snippets.compile <<-CRYSTAL
      require "./src/cql"

      class BrokenBelongsTo
        include CQL::ActiveRecord::Model(Int32)

        property user_id : Int32?

        belongs_to "user", MissingUser, :user_id
      end
      CRYSTAL

    success.should be_false
    error.should contain("CQL belongs_to error")
    error.should contain("association name must be a symbol literal")
  end

  it "raises a clear error for unsupported has_many dependent options" do
    success, _output, error = Snippets.compile <<-CRYSTAL
      require "./src/cql"

      class BrokenHasMany
        include CQL::ActiveRecord::Model(Int32)

        has_many :posts, MissingPost, dependent: :explode
      end
      CRYSTAL

    success.should be_false
    error.should contain("CQL has_many error")
    error.should contain("unsupported dependent option `:explode`")
  end

  it "raises a clear error for unsupported has_one dependent options" do
    success, _output, error = Snippets.compile <<-CRYSTAL
      require "./src/cql"

      class BrokenHasOne
        include CQL::ActiveRecord::Model(Int32)

        has_one :profile, MissingProfile, dependent: :delete_all
      end
      CRYSTAL

    success.should be_false
    error.should contain("CQL has_one error")
    error.should contain("unsupported dependent option `:delete_all`")
  end

  it "raises a clear error for unsupported many_to_many dependent options" do
    success, _output, error = Snippets.compile <<-CRYSTAL
      require "./src/cql"

      class BrokenManyToMany
        include CQL::ActiveRecord::Model(Int32)

        many_to_many :tags, MissingTag, join_through: :missing_tags, dependent: :restrict_with_error
      end
      CRYSTAL

    success.should be_false
    error.should contain("CQL many_to_many error")
    error.should contain("unsupported dependent option `:restrict_with_error`")
  end

  it "raises a clear error when belongs_to foreign key type does not match target primary key type" do
    success, _output, error = Snippets.compile <<-CRYSTAL
      require "./src/cql"

      class MismatchedUser
        include CQL::ActiveRecord::Model(Int64)
      end

      class MismatchedPost
        include CQL::ActiveRecord::Model(Int32)

        property user_id : Int32?

        belongs_to :user, MismatchedUser, :user_id
      end
      CRYSTAL

    success.should be_false
    error.should contain("CQL belongs_to error")
    error.should contain("foreign key `:user_id` type Int32 does not match MismatchedUser.id! primary key type Int64")
  end

  it "raises a clear error when a later-defined belongs_to target has a mismatched primary key type" do
    success, _output, error = Snippets.compile <<-CRYSTAL
      require "./src/cql"

      class ForwardPost
        include CQL::ActiveRecord::Model(Int32)

        property user_id : Int32?

        belongs_to :user, ForwardUser, :user_id
      end

      class ForwardUser
        include CQL::ActiveRecord::Model(Int64)
      end
      CRYSTAL

    success.should be_false
    error.should contain("CQL belongs_to error")
    error.should contain("foreign key `:user_id` type Int32 does not match ForwardUser.id! primary key type Int64")
  end

  it "raises a clear error when has_many target foreign key type does not match parent primary key type" do
    success, _output, error = Snippets.compile <<-CRYSTAL
      require "./src/cql"

      class MismatchedComment
        include CQL::ActiveRecord::Model(Int32)

        property post_id : Int32?
      end

      class MismatchedPost
        include CQL::ActiveRecord::Model(Int64)

        has_many :comments, MismatchedComment, foreign_key: :post_id
      end
      CRYSTAL

    success.should be_false
    error.should contain("CQL has_many error")
    error.should contain("target foreign key MismatchedComment#post_id type Int32 does not match MismatchedPost.id! primary key type Int64")
  end

  it "raises a clear error when a later-defined has_many target has a mismatched foreign key type" do
    success, _output, error = Snippets.compile <<-CRYSTAL
      require "./src/cql"

      class ForwardPost
        include CQL::ActiveRecord::Model(Int64)

        has_many :comments, ForwardComment, foreign_key: :post_id
      end

      class ForwardComment
        include CQL::ActiveRecord::Model(Int32)

        property post_id : Int32?
      end
      CRYSTAL

    success.should be_false
    error.should contain("CQL has_many error")
    error.should contain("target foreign key ForwardComment#post_id type Int32 does not match ForwardPost.id! primary key type Int64")
  end

  it "raises a clear schema mapping error when model getter type does not match schema column type" do
    db_path = File.join(Dir.tempdir, "cql_broken_schema_#{Random.rand(1_000_000)}.db")
    success, _output, error = Snippets.run <<-CRYSTAL
      require "sqlite3"
      require "./src/cql"

      ENV["CQL_VALIDATE_SCHEMA_MAPPINGS"] = "1"

      BrokenSchema = CQL::Schema.define(
        :broken_schema,
        "sqlite3://#{db_path}",
        CQL::Adapter::SQLite
      ) do
        table :broken_users do
          primary :id, Int32
          column :name, String
        end
      end

      class BrokenUser
        include CQL::ActiveRecord::Model(Int32)

        db_context BrokenSchema, :broken_users

        property name : Int32
      end
      CRYSTAL

    success.should be_false
    error.should contain("CQL schema mapping error")
    error.should contain("schema column `broken_users.name` type String does not match model getter `name` type Int32")
  ensure
    File.delete(db_path) if db_path && File.exists?(db_path)
  end
end
