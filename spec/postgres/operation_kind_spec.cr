require "../spec_helper"
require "../../src/postgres"

describe CQL::Postgres::OperationKind do
  it "labels plain statements by their first word" do
    {"SELECT 1" => :select, "  insert into t values (1)" => :insert, "UPDATE t SET a = 1" => :update, "delete from t" => :delete,
     "/* hint */ INSERT INTO t DEFAULT VALUES" => :insert, "-- note\nDELETE FROM t" => :delete, "EXPLAIN SELECT 1" => :select}.each do |sql, kind|
      CQL::Postgres::OperationKind.of(sql).should eq kind
    end
  end

  it "labels a WITH query by the data-modifying statement it contains" do
    CQL::Postgres::OperationKind.of("WITH ins AS (INSERT INTO t VALUES (1) RETURNING id) SELECT id FROM ins").should eq :insert
    CQL::Postgres::OperationKind.of("with moved as (delete from a returning *) insert into b select * from moved").should eq :delete
    CQL::Postgres::OperationKind.of("WITH x AS (SELECT 1) UPDATE t SET a = 1 FROM x").should eq :update
  end

  it "reads WITH RECURSIVE, upserts, doubled quotes, block comments and every row lock" do
    {"WITH RECURSIVE r AS (SELECT 1) SELECT * FROM r"                                     => :select,
     "WITH s AS (SELECT 1) INSERT INTO t SELECT * FROM s ON CONFLICT DO UPDATE SET a = 1" => :insert,
     "WITH x AS (SELECT 'it''s delete time') SELECT * FROM x"                             => :select,
     "WITH x AS (SELECT 1 /* delete */) SELECT * FROM x"                                  => :select,
     "WITH x AS (SELECT id FROM t FOR NO KEY UPDATE) SELECT id FROM x"                    => :select,
     "WITH x AS (SELECT id FROM t FOR SHARE) SELECT id FROM x"                            => :select}.each do |sql, kind|
      CQL::Postgres::OperationKind.of(sql).should eq kind
    end
  end

  it "handles a huge literal without running out of regex stack" do
    CQL::Postgres::OperationKind.of("WITH x AS (SELECT '#{"a'' b" * 300_000}') SELECT * FROM x").should eq :select
  end

  it "keeps read-only WITH queries as selects, whatever the text or locks say" do
    CQL::Postgres::OperationKind.of("WITH x AS (SELECT 1) SELECT * FROM x").should eq :select
    CQL::Postgres::OperationKind.of("WITH x AS (SELECT 'delete me' AS note) SELECT note FROM x").should eq :select
    CQL::Postgres::OperationKind.of("WITH x AS (SELECT id FROM t FOR UPDATE) SELECT id FROM x").should eq :select
    CQL::Postgres::OperationKind.of("WITH x AS (SELECT 1 AS \"update\") SELECT * FROM x -- insert later").should eq :select
  end
end
