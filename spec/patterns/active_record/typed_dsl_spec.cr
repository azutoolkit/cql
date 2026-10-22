require "../../spec_helper"

DSL_DB = CQL::Schema.define(:typed_dsl, adapter: CQL::Adapter::SQLite, uri: spec_sqlite_uri("typed_dsl.db")) do
  table :authors do
    primary :id, Int64
    column :name, String
    column :age, Int32
    column :status, String
    column :score, Float64, null: true
    column :created_at, Time, null: true
  end

  table :profiles do
    primary :id, Int64
    column :author_id, Int64
    column :country, String
  end

  table :books do
    primary :id, Int64
    column :title, String
    column :author_id, Int64
    column :pages, Int32
  end
end

class DslAuthor
  include CQL::ActiveRecord::Model(Int64)
  db_context DSL_DB, :authors

  property name : String
  property age : Int32
  property status : String
  property score : Float64?
  property created_at : Time?

  has_one :profile, DslProfile, foreign_key: :author_id
  has_many :books, DslBook, foreign_key: :author_id

  def initialize(@name, @age, @status = "active", @score = nil, @created_at = nil)
  end

  def shout : String
    name.upcase
  end
end

class DslProfile
  include CQL::ActiveRecord::Model(Int64)
  db_context DSL_DB, :profiles

  property author_id : Int64
  property country : String

  belongs_to :author, DslAuthor, :author_id

  def initialize(@author_id, @country)
  end
end

class DslBook
  include CQL::ActiveRecord::Model(Int64)
  db_context DSL_DB, :books

  property title : String
  property author_id : Int64
  property pages : Int32

  belongs_to :author, DslAuthor, :author_id

  def initialize(@title, @author_id, @pages)
  end
end

describe "Typed query DSL" do
  sql_of = ->(builder : CQL::ActiveRecord::Queryable::QueryBuilder(DslAuthor)) { builder.query.to_sql }

  describe "where { } blocks" do
    it "uses bare column names with typed operators" do
      sql, params = sql_of.call(DslAuthor.query.where { (age >= 18) & (status == "active") })

      sql.should end_with("WHERE (authors.age >= ?) AND (authors.status = ?)")
      params.should eq([18, "active"] of DB::Any)
    end

    it "also accepts a block parameter" do
      sql, _ = sql_of.call(DslAuthor.query.where { |author| author.age < 30 })
      sql.should end_with("WHERE authors.age < ?")
    end

    it "supports |, not, and chained wheres" do
      sql, _ = sql_of.call(DslAuthor.query.where { (age < 18) | (age > 65) })
      sql.should end_with("WHERE (authors.age < ?) OR (authors.age > ?)")

      sql, _ = sql_of.call(DslAuthor.query.where { (status == "banned").not })
      sql.should end_with("WHERE NOT (authors.status = ?)")

      sql, _ = sql_of.call(DslAuthor.query.where { age > 1 }.where { status == "x" })
      sql.should end_with("WHERE (authors.age > ?) AND (authors.status = ?)")
    end

    it "supports in, between, like, null checks and == nil" do
      sql, params = sql_of.call(DslAuthor.query.where { age.in([1, 2, 3]) & age.between(1, 9) & name.like("A%") })
      sql.should contain("authors.age IN (?, ?, ?)")
      sql.should contain("authors.age BETWEEN ? AND ?")
      sql.should contain("authors.name LIKE ?")
      params.size.should eq(6)

      sql_of.call(DslAuthor.query.where { score.null }).first.should end_with("WHERE authors.score IS NULL")
      sql_of.call(DslAuthor.query.where { score == nil }).first.should end_with("WHERE authors.score IS NULL")
      sql_of.call(DslAuthor.query.where { score != nil }).first.should end_with("WHERE authors.score IS NOT NULL")
      sql_of.call(DslAuthor.query.where { name.ilike("a%") }).first.should contain("LOWER(authors.name) LIKE LOWER(?)")
    end

    it "accepts numeric literals for wider numeric columns" do
      sql_of.call(DslAuthor.query.where { score > 1 }).last.should eq([1.0] of DB::Any)
      sql_of.call(DslAuthor.query.where { id == 7 }).last.should eq([7] of DB::Any)
    end

    it "is available on the model class and does not mutate the builder it extends" do
      base = DslAuthor.query
      base.where { age > 1 }

      sql_of.call(base).first.should_not contain("WHERE")
      DslAuthor.where { age > 1 }.query.to_sql.first.should end_with("WHERE authors.age > ?")
    end

    it "keeps working with explicit table_column blocks" do
      DslAuthor.where { DslAuthor.table_column(:age).gt(1) }.query.to_sql.first.should end_with("WHERE authors.age > ?")
    end
  end

  describe "joins" do
    it "joins a has_one association with a typed condition on the joined table" do
      sql, params = sql_of.call(DslAuthor.query.joins(:profile) { profile.country == "US" })

      sql.should contain("INNER JOIN profiles ON (profiles.author_id = authors.id) AND (profiles.country = ?)")
      params.should eq(["US"] of DB::Any)
    end

    it "joins has_many and belongs_to associations, without a condition" do
      sql_of.call(DslAuthor.query.joins(:books)).first.should contain("INNER JOIN books ON books.author_id = authors.id")
      DslBook.query.joins(:author).query.to_sql.first.should contain("INNER JOIN authors ON authors.id = books.author_id")
    end

    it "supports left joins and conditions on the base table in the same block" do
      sql, _ = sql_of.call(DslAuthor.query.left_joins(:profile) { (profile.country == "US") & (age > 1) })
      sql.should contain("LEFT JOIN profiles ON (profiles.author_id = authors.id) AND ((profiles.country = ?) AND (authors.age > ?))")
    end

    it "rejects unknown associations at runtime and lists the valid ones" do
      expect_raises(ArgumentError, /DslAuthor has no association :nope.*profile, books/) { DslAuthor.query.joins(:nope) }
    end

    it "filters through a join when executed" do
      DSL_DB.authors.create!
      DSL_DB.profiles.create!
      begin
        ada = DslAuthor.new("Ada", 36).tap(&.save!)
        grace = DslAuthor.new("Grace", 45).tap(&.save!)
        DslProfile.new(ada.id!, "US").save!
        DslProfile.new(grace.id!, "UK").save!

        DslAuthor.query.joins(:profile) { profile.country == "US" }.to_a.map(&.name).should eq(["Ada"])
      ensure
        DSL_DB.profiles.drop!
        DSL_DB.authors.drop!
      end
    end
  end

  describe "regressions from review" do
    before_each do
      DSL_DB.authors.create!
      DSL_DB.books.create!
      DSL_DB.profiles.create!
    end
    after_each do
      DSL_DB.authors.drop!
      DSL_DB.books.drop!
      DSL_DB.profiles.drop!
    end

    it "keeps the model's own id when joining a table that also has an id" do
      ada = DslAuthor.new("Ada", 36).tap(&.save!)
      DslBook.new("A", 1_i64, 10).save!
      DslBook.new("B", 1_i64, 20).save!
      DslBook.new("C", 1_i64, 30).save!

      DslAuthor.query.joins(:books).to_a.map(&.id).should eq([ada.id] * 3)
    end

    it "keeps aggregates and pluck correct when joining" do
      DslAuthor.new("Ada", 36).save!
      DslBook.new("A", 1_i64, 10).save!
      DslBook.new("B", 1_i64, 20).save!

      DslAuthor.query.joins(:books).count.should eq(2)
      DslAuthor.query.joins(:books).pluck(:name, as: String).should eq(["Ada", "Ada"])
    end

    it "paginates with find_each across a join and refuses preload after select" do
      DslAuthor.new("Ada", 36).save!
      DslBook.new("A", 1_i64, 10).save!

      names = [] of String
      DslAuthor.query.joins(:books).find_each { |author| names << author.name }
      names.should eq(["Ada"])
      expect_raises(ArgumentError, /preload/) { DslAuthor.query.select(:name).preload(:books) }
    end

    it "does not treat computed methods as columns" do
      DslAuthor.cql_column_names.should_not contain(:shout)
      DslAuthor.cql_column_names.should contain(:name)
    end

    it "widens integer lists against an Int64 column" do
      DslAuthor.new("Ada", 36).save!
      DslAuthor.query.where { id.in([1, 2]) }.to_a.size.should eq(1)
      DslAuthor.query.where { id.not_in([1, 2]) }.to_a.size.should eq(0)
    end

    it "names the column when an integer literal does not fit" do
      expect_raises(ArgumentError, /3000000000 does not fit a Int32/) do
        DslAuthor.query.where { age == 3_000_000_000 }
      end
    end
  end

  describe "order_by and to_a" do
    it "orders by typed columns" do
      sql, _ = sql_of.call(DslAuthor.query.order_by(created_at: :desc, name: :asc))
      sql.should end_with("ORDER BY authors.created_at DESC, authors.name ASC")
    end

    it "to_a is all" do
      DSL_DB.authors.create!
      begin
        DslAuthor.new("Ada", 36).save!
        DslAuthor.query.to_a.map(&.name).should eq(["Ada"])
      ensure
        DSL_DB.authors.drop!
      end
    end
  end

  describe "select with symbols" do
    before_each do
      DSL_DB.authors.create!
      DslAuthor.new("Ada", 36, "active", 1.5).save!
      DslAuthor.new("Grace", 45).save!
    end
    after_each { DSL_DB.authors.drop! }

    it "returns lightweight rows with only the selected columns filled in" do
      rows = DslAuthor.query.where { age >= 18 }.select(:id, :name).order_by(age: :desc).limit(1).to_a

      rows.size.should eq(1)
      rows.first.name.should eq("Grace")
      rows.first.id.should_not be_nil
      rows.first.age.should be_nil
    end

    it "keeps the chain after select" do
      builder = DslAuthor.query.select(:name)
      builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(DslAuthor))
      builder.where { age > 40 }.to_a.map(&.name).should eq(["Grace"])
    end

    it "rejects unknown columns with the model and its columns" do
      expect_raises(ArgumentError, /DslAuthor has no column :nope/) { DslAuthor.query.select(:name, :nope) }
    end
  end

  describe "the headline query" do
    it "composes where, joins, select, order_by, limit and to_a" do
      DSL_DB.authors.create!
      DSL_DB.profiles.create!
      begin
        ada = DslAuthor.new("Ada", 36).tap(&.save!)
        grace = DslAuthor.new("Grace", 45).tap(&.save!)
        minor = DslAuthor.new("Kid", 12).tap(&.save!)
        [{ada, "US"}, {grace, "US"}, {minor, "US"}].each { |author, country| DslProfile.new(author.id!, country).save! }

        names = DslAuthor.query
          .where { (age >= 18) & (status == "active") }
          .joins(:profile) { profile.country == "US" }
          .select(:id, :name, :created_at)
          .order_by(age: :desc)
          .limit(20)
          .to_a
          .map(&.name)

        names.should eq(["Grace", "Ada"])
      ensure
        DSL_DB.profiles.drop!
        DSL_DB.authors.drop!
      end
    end
  end

  describe "compile-time safety" do
    preamble = <<-CRYSTAL
      require "./src/cql"
      require "sqlite3"

      DB_ = CQL::Schema.define(:snippet, adapter: CQL::Adapter::SQLite, uri: "sqlite3://%3Amemory%3A") do
        table :authors do
          primary :id, Int64
          column :name, String
          column :age, Int32
        end
        table :books do
          primary :id, Int64
          column :author_id, Int64
        end
      end

      class SnipAuthor
        include CQL::ActiveRecord::Model(Int64)
        db_context DB_, :authors
        property name : String
        property age : Int32
        has_many :books, SnipBook, foreign_key: :author_id
        def initialize(@name, @age); end
      end

      class SnipBook
        include CQL::ActiveRecord::Model(Int64)
        db_context DB_, :books
        property author_id : Int64
        belongs_to :author, SnipAuthor, :author_id
        def initialize(@author_id); end
      end
      CRYSTAL

    it "accepts valid queries" do
      success, _, error = Snippets.compile(preamble + "\nSnipAuthor.query.where { age > 1 }.joins(:books) { books.author_id > 0 }.order_by(name: :asc)\n")
      error.should eq("") if success
      success.should be_true
    end

    it "rejects unknown columns in where blocks, naming the model and columns" do
      success, _, error = Snippets.compile(preamble + "\nSnipAuthor.query.where { agee > 1 }\n")

      success.should be_false
      error.should contain("SnipAuthor")
      error.should contain("agee")
    end

    it "rejects comparing a column with the wrong type" do
      success, _, error = Snippets.compile(preamble + %(\nSnipAuthor.query.where { age > "old" }\n))

      success.should be_false
      error.should contain("CQL")
      error.should contain("Int32")
      error.should contain("String")
    end

    it "rejects unknown columns in order_by" do
      success, _, error = Snippets.compile(preamble + "\nSnipAuthor.query.order_by(nope: :asc)\n")

      success.should be_false
      error.should contain("order_by")
      error.should contain("nope")
    end

    it "rejects a column of another table inside a joins block" do
      success, _, error = Snippets.compile(preamble + "\nSnipAuthor.query.joins(:books) { name_of_book == 1 }\n")
      success.should be_false
    end
  end
end
