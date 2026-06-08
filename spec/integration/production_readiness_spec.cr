require "../spec_helper"

ProductionReadinessDB = CQL::Schema.define(
  :production_readiness_db,
  adapter: CQL::Adapter::SQLite,
  uri: spec_sqlite_uri("production_readiness.db")
) do
  table :stress_records do
    primary :id, Int64, auto_increment: true
    integer :bucket
  end

  table :authors do
    primary :id, Int64, auto_increment: true
    text :name
  end

  table :posts do
    primary :id, Int64, auto_increment: true
    text :title
    bigint :author_id
    foreign_key [:author_id], references: :authors, references_columns: [:id]
  end

  table :comments do
    primary :id, Int64, auto_increment: true
    text :body
    bigint :post_id
    foreign_key [:post_id], references: :posts, references_columns: [:id]
  end
end

describe "Production readiness integration coverage" do
  before_all do
    ProductionReadinessDB.comments.drop! rescue nil
    ProductionReadinessDB.posts.drop! rescue nil
    ProductionReadinessDB.authors.drop! rescue nil
    ProductionReadinessDB.stress_records.drop! rescue nil

    ProductionReadinessDB.stress_records.create!
    ProductionReadinessDB.authors.create!
    ProductionReadinessDB.posts.create!
    ProductionReadinessDB.comments.create!
  end

  after_all do
    ProductionReadinessDB.comments.drop! rescue nil
    ProductionReadinessDB.posts.drop! rescue nil
    ProductionReadinessDB.authors.drop! rescue nil
    ProductionReadinessDB.stress_records.drop! rescue nil
  end

  before_each do
    ProductionReadinessDB.exec("DELETE FROM comments")
    ProductionReadinessDB.exec("DELETE FROM posts")
    ProductionReadinessDB.exec("DELETE FROM authors")
    ProductionReadinessDB.exec("DELETE FROM stress_records")
  end

  it "serves concurrent fiber reads through pooled connections" do
    ProductionReadinessDB.insert
      .into(:stress_records)
      .values((1..100).map { |i| {:bucket => (i % 10).as(DB::Any)} })
      .commit

    results = Channel(Int64).new(32)

    32.times do |i|
      spawn do
        count = ProductionReadinessDB.exec_query do |conn|
          conn.query_one("SELECT COUNT(*) FROM stress_records WHERE bucket = ?", i % 10, as: Int64)
        end
        results.send(count)
      end
    end

    32.times do
      results.receive.should eq(10)
    end
  end

  it "executes a 5,000 row batch insert as one multi-value statement" do
    rows = (1..5_000).map { |i| {:bucket => (i % 100).as(DB::Any)} }
    insert = ProductionReadinessDB.insert.into(:stress_records).values(rows)
    sql, params = insert.to_sql

    sql.should contain("VALUES")
    sql.scan(/\(\?\)/).size.should eq(5_000)
    params.size.should eq(5_000)

    insert.commit

    count = ProductionReadinessDB.exec_query do |conn|
      conn.query_one("SELECT COUNT(*) FROM stress_records", as: Int64)
    end

    count.should eq(5_000)
  end

  it "builds deterministic SQL for a deep nested join chain" do
    sql, params = ProductionReadinessDB.query
      .from(:authors)
      .join(:posts)
      .join(:comments)
      .select(authors: [:name], posts: [:title], comments: [:body])
      .where { authors.name.eq("Ada") & comments.body.is_not_null }
      .to_sql

    sql.should eq("SELECT authors.name, posts.title, comments.body FROM authors INNER JOIN posts ON posts.author_id = authors.id INNER JOIN comments ON comments.post_id = posts.id WHERE (authors.name = ?) AND (comments.body IS NOT NULL)")
    params.should eq(["Ada"] of DB::Any)
  end
end
