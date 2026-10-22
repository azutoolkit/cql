require "../spec_helper"

describe "Aggregate select-list aliases" do
  it "emits AS for each aggregate when an alias is given" do
    sql, _ = Northwind.query.from(:orders)
      .count(:id, as: "order_count")
      .sum(:total, as: "revenue")
      .avg(:total, as: "avg_total")
      .min(:total, as: "smallest")
      .max(:total, as: "largest")
      .to_sql

    sql.should eq(
      "SELECT COUNT(orders.id) AS order_count, SUM(orders.total) AS revenue, " \
      "AVG(orders.total) AS avg_total, MIN(orders.total) AS smallest, " \
      "MAX(orders.total) AS largest FROM orders")
  end

  it "aliases COUNT(*)" do
    sql, _ = Northwind.query.from(:orders).count(as: "n").to_sql
    sql.should eq("SELECT COUNT(*) AS n FROM orders")
  end

  it "leaves aggregates without an alias unchanged" do
    sql, _ = Northwind.query.from(:orders).count(:id).to_sql
    sql.should eq("SELECT COUNT(orders.id) FROM orders")
  end

  it "does not emit the alias inside HAVING" do
    sql, _ = Northwind.query.from(:orders)
      .select(:customer_id)
      .count(:id, as: "n")
      .group(:customer_id)
      .having { count(:id) > 1 }
      .to_sql

    sql.should contain("COUNT(orders.id) AS n")
    sql.should match(/HAVING COUNT\(orders\.id\) > \?/)
    sql.should_not match(/HAVING .*AS n/)
  end

  it "rejects aliases that are not plain identifiers" do
    expect_raises(ArgumentError, /Invalid alias/) do
      Northwind.query.from(:orders).count(:id, as: "n; DROP TABLE orders")
    end
  end
end
