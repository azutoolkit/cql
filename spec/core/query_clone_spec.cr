require "../spec_helper"

describe "CQL::Query#clone" do
  base = -> { Northwind.query.from(:users).where(name: "Ada").order(name: :asc).limit(5).offset(2) }

  it "keeps the clauses of the original" do
    original = base.call
    original.clone.to_sql.should eq(original.to_sql)
  end

  it "carries every clause collection over and keeps each independent" do
    original = Northwind.query.from(:users)
      .join(:address) { |j| j.users.id.eq(j.address.user_id) }
      .select(users: [:name])
      .group(:name)
      .distinct_on(:name)
      .count(:email)
      .with(:recent, Northwind.query.from(:users).select(:id))
    copy = original.clone
    postgres = -> { Expression::Generator.new(CQL::Adapter::Postgres) }
    sql_before = original.to_sql(postgres.call)

    copy.to_sql(postgres.call).should eq(sql_before)
    copy.columns.clear
    copy.joins.clear
    copy.group_by.clear
    copy.select_expressions.clear
    copy.distinct_on.clear
    copy.ctes.clear
    copy.derived_tables.clear
    copy.order_by.clear

    original.to_sql(postgres.call).should eq(sql_before)
  end

  it "does not leak changes made on the original into the clone" do
    original = base.call
    copy = original.clone
    copy_sql = copy.to_sql

    original.group(:email).distinct_on(:name).count(:id).join(:address) { |j| j.users.id.eq(j.address.user_id) }

    copy.to_sql.should eq(copy_sql)
  end

  it "copies the scalar settings" do
    original = base.call.distinct
    copy = original.clone

    copy.limit.should eq(5)
    copy.offset.should eq(2)
    copy.distinct?.should be_true
    copy.where.should be(original.where)
  end

  it "lets a fresh query take clauses through its collection getters" do
    query = Northwind.query.from(:users)
    query.select_expressions << Expression::Count.new(Expression::Column.new(query.query_tables["users"][:table].columns[:id], alias_name: "users"))

    query.to_sql.first.should contain("COUNT(users.id)")
  end

  describe "collection predicates" do
    it "report content without allocating and follow resets" do
      query = Northwind.query.from(:users)
      query.order_by?.should be_false
      query.order_by.empty?.should be_true
      query.order_by?.should be_false

      query.order(:name)
      query.order_by?.should be_true
      query.reorder(:email).order_by?.should be_true
      query.unscope(:order).order_by?.should be_false

      query.group(:name).group_by?.should be_true
      query.unscope(:group).group_by?.should be_false

      query.join(:address) { |j| j.users.id.eq(j.address.user_id) }.joins?.should be_true
      query.from(:users).joins?.should be_false
    end

    it "gives a clone its own collection when the original's is allocated but empty" do
      original = Northwind.query.from(:users)
      original.order_by
      copy = original.clone

      copy.order(:name)

      original.order_by?.should be_false
    end
  end
end
