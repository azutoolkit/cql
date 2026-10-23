require "../spec_helper"
require "../../src/postgres"
require "../../src/postgres/session"

private def statement(name : String) : CQL::Postgres::PreparedStatement
  CQL::Postgres::PreparedStatement.new(name, 0, [] of CQL::Postgres::Column)
end

describe CQL::Postgres::StatementCache do
  it "is disabled at capacity zero" do
    CQL::Postgres::StatementCache.new(0).enabled?.should be_false
    CQL::Postgres::StatementCache.new(1).enabled?.should be_true
  end

  it "hands out unique statement names" do
    cache = CQL::Postgres::StatementCache.new(2)
    {cache.next_name, cache.next_name}.should eq({"cql_1", "cql_2"})
  end

  it "evicts the least recently used statements to make room" do
    cache = CQL::Postgres::StatementCache.new(2)
    cache.store("a", statement("sa"))
    cache.store("b", statement("sb"))
    cache.fetch("a") # a is now the most recent
    cache.evict(room: 1).map(&.name).should eq ["sb"]
    cache.fetch("b").should be_nil
    cache.fetch("a").should_not be_nil
  end

  it "evicts several at once when a batch needs room, sparing statements about to be used" do
    cache = CQL::Postgres::StatementCache.new(3)
    {"a", "b", "c"}.each { |sql| cache.store(sql, statement("s#{sql}")) }
    cache.evict(room: 2, keep: Set{"sa"}).map(&.name).should eq ["sb", "sc"]
    cache.size.should eq 1
  end

  it "evicts nothing while there is room" do
    cache = CQL::Postgres::StatementCache.new(2)
    cache.store("a", statement("sa"))
    cache.evict(room: 1).should be_empty
  end

  it "forgets a deleted statement" do
    cache = CQL::Postgres::StatementCache.new(2)
    cache.store("a", statement("sa"))
    cache.delete("a").try(&.name).should eq "sa"
    cache.fetch("a").should be_nil
  end
end
