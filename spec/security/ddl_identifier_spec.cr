require "../spec_helper"

# Names that are spliced into DDL as identifiers (they cannot be bound as
# parameters) are restricted to plain identifier characters.
describe "DDL identifier validation" do
  pg = -> { Expression::Generator.new(CQL::Adapter::Postgres) }
  hostile = "x; DROP TABLE users; --"

  describe "indexes" do
    it "accepts plain index names" do
      index = CQL::Index.new(Northwind.users, [:email], unique: true, name: "idx_users_email")
      sql = Expression::CreateIndex.new(index).accept(pg.call)

      sql.should contain("idx_users_email")
    end

    it "rejects hostile index names on create and drop" do
      index = CQL::Index.new(Northwind.users, [:email], name: hostile)

      expect_raises(ArgumentError, /Invalid index name/) { Expression::CreateIndex.new(index).accept(pg.call) }
      expect_raises(ArgumentError, /Invalid index name/) { Expression::DropIndex.new(index).accept(pg.call) }
    end

    it "allows a schema-qualified name when dropping an index" do
      index = CQL::Index.new(Northwind.users, [:email], name: "myschema.idx_users_email")
      Expression::DropIndex.new(index).accept(pg.call).should contain("myschema.idx_users_email")
    end

    it "still rejects qualified names on create" do
      index = CQL::Index.new(Northwind.users, [:email], name: "myschema.idx")
      expect_raises(ArgumentError, /Invalid index name/) { Expression::CreateIndex.new(index).accept(pg.call) }
    end
  end

  describe "foreign keys" do
    it "rejects hostile names on add and drop" do
      fk = CQL::ForeignKey.new(Northwind.orders, [:customer_id], :customers, [:id], name: hostile)

      expect_raises(ArgumentError, /Invalid foreign key name/) { Expression::AddForeignKey.new(fk).accept(pg.call) }
      expect_raises(ArgumentError, /Invalid foreign key name/) do
        Expression::DropForeignKey.new(hostile, "orders").accept(pg.call)
      end
    end

    it "rejects hostile referenced tables and columns" do
      table_fk = CQL::ForeignKey.new(Northwind.orders, [:customer_id], :"customers (id); DROP TABLE x; --", [:id])
      col_fk = CQL::ForeignKey.new(Northwind.orders, [:customer_id], :customers, [:"id) ; DROP"])
      local_fk = CQL::ForeignKey.new(Northwind.orders, [:"a b"], :customers, [:id])

      expect_raises(ArgumentError, /Invalid table name/) { Expression::AddForeignKey.new(table_fk).accept(pg.call) }
      expect_raises(ArgumentError, /Invalid column name/) { Expression::AddForeignKey.new(col_fk).accept(pg.call) }
      expect_raises(ArgumentError, /Invalid column name/) { Expression::AddForeignKey.new(local_fk).accept(pg.call) }
    end

    it "generates the default single-column name" do
      fk = CQL::ForeignKey.new(Northwind.orders, [:customer_id], :customers, [:id])
      sql = Expression::AddForeignKey.new(fk).accept(pg.call)

      sql.should contain("fk_orders_customer_id")
      sql.should contain("FOREIGN KEY (customer_id) REFERENCES customers (id)")
    end

    it "generates the default composite name" do
      fk = CQL::ForeignKey.new(Northwind.orders, [:customer_id, :region_id], :customers, [:id, :region])
      sql = Expression::AddForeignKey.new(fk).accept(pg.call)

      sql.should contain("fk_orders_customer_id_region_id")
      sql.should contain("FOREIGN KEY (customer_id, region_id) REFERENCES customers (id, region)")
    end

    it "keeps a valid explicit name" do
      fk = CQL::ForeignKey.new(Northwind.orders, [:customer_id], :customers, [:id], name: "fk_orders_customers")
      Expression::AddForeignKey.new(fk).accept(pg.call).should contain("fk_orders_customers")
    end
  end

  describe "renames" do
    it "rejects hostile table and column names" do
      expect_raises(ArgumentError, /Invalid table name/) do
        Expression::RenameTable.new(Northwind.users, hostile).accept(pg.call)
      end
      expect_raises(ArgumentError, /Invalid column name/) do
        Expression::RenameColumn.new(Northwind.users.columns[:email], hostile).accept(pg.call)
      end
    end

    it "accepts valid new names" do
      Expression::RenameTable.new(Northwind.users, "people").accept(pg.call).should contain("people")
      Expression::RenameColumn.new(Northwind.users.columns[:email], "mail").accept(pg.call).should contain("mail")
    end
  end

  describe "CREATE TABLE inline constraints" do
    it "rejects hostile constraint names" do
      [
        ->(t : CQL::Table) { t.foreign_keys << CQL::ForeignKey.new(t, [:customer_id], :customers, [:id], name: hostile) },
        ->(t : CQL::Table) { t.unique_constraints << CQL::UniqueConstraint.new([:email], hostile) },
        ->(t : CQL::Table) { t.check_constraints << CQL::CheckConstraint.new("total > 0", hostile) },
      ].each do |add|
        table = CQL::Table.new(:scratch, Northwind)
        add.call(table)

        expect_raises(ArgumentError, /Invalid .* name/) { Expression::CreateTable.new(table).accept(pg.call) }
      end
    end
  end
end
