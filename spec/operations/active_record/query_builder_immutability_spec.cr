require "../../spec_helper"

# QueryBuilder methods must return a new builder and leave the receiver intact,
# so a builder can be stored, reused and branched safely.
describe CQL::ActiveRecord::Queryable::QueryBuilder do
  before_each do
    UserDB.users.create!
    UserDB.posts.create!
  end

  after_each do
    UserDB.posts.drop!
    UserDB.users.drop!
  end

  sql_of = ->(builder : CQL::ActiveRecord::Queryable::QueryBuilder(TestUser)) { builder.query.to_sql[0] }

  it "block where does not mutate the receiver" do
    base = TestUser.query
    filtered = base.where { TestUser.table_column(:age).gt(10) }

    sql_of.call(base).should_not contain("WHERE")
    sql_of.call(filtered).should contain("WHERE")
  end

  it "block join does not mutate the receiver" do
    base = TestUser.query
    joined = base.join(:posts) { |j| j.posts.user_id.eq(j.users.id) }

    sql_of.call(base).should_not contain("JOIN")
    sql_of.call(joined).should contain("INNER JOIN posts")
  end

  it "block left and right joins do not mutate the receiver" do
    base = TestUser.query
    base.left(:posts) { |j| j.posts.user_id.eq(j.users.id) }
    base.right(:posts) { |j| j.posts.user_id.eq(j.users.id) }

    sql_of.call(base).should_not contain("JOIN")
  end

  it "having applies to HAVING and not WHERE" do
    builder = TestUser.query.group(:age).having { count(:id) > 1 }
    sql = sql_of.call(builder)

    sql.should contain("HAVING")
    sql.should_not contain("WHERE")
  end

  it "aggregates do not leak into later queries on the same builder" do
    builder = TestUser.query.where(age: 30)
    builder.count
    builder.sum(:age)

    sql = sql_of.call(builder)
    sql.should_not contain("COUNT")
    sql.should_not contain("SUM")
  end

  it "ids does not narrow the receiver's select list" do
    builder = TestUser.query
    builder.ids

    sql_of.call(builder).should contain("users.name")
  end

  it "reorder replaces ordering on a copy only" do
    original = TestUser.query.order(name: :asc)
    reordered = original.reorder(age: :desc)

    sql_of.call(original).should contain("ORDER BY users.name ASC")
    sql_of.call(reordered).should contain("ORDER BY users.age DESC")
    sql_of.call(reordered).should_not contain("users.name ASC")
  end

  it "reverse_order flips the direction on a copy" do
    original = TestUser.query.order(name: :asc)
    reversed = original.reverse_order

    sql_of.call(reversed).should contain("ORDER BY users.name DESC")
    sql_of.call(original).should contain("ORDER BY users.name ASC")
  end

  it "unscope removes the named clause on a copy" do
    original = TestUser.query.where(age: 30).order(name: :asc).limit(5)
    stripped = original.unscope(:where).unscope(:order).unscope(:limit)

    sql_of.call(stripped).should_not contain("WHERE")
    sql_of.call(stripped).should_not contain("ORDER BY")
    sql_of.call(original).should contain("WHERE")
  end
end
