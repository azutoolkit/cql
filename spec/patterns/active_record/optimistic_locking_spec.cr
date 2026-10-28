require "./spec_helper"
# Create a test schema with our test tables
OPTIMISTIC_LOCKING_TEST_SCHEMA = CQL::Schema.define(
  :optimistic_locking_test,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3::memory:") do
  # Create a test table with a version column for optimistic locking
  table :products do
    primary :id, Int32, auto_increment: true
    varchar :name
    double :price, default: 0.0
    integer :stock, default: 0
    lock_version :version
    timestamps
  end

  table :int64_products do
    primary :id, Int64, auto_increment: true
    varchar :name
    double :price, default: 0.0
    integer :stock, default: 0
    lock_version :version
    timestamps
  end

  table :soft_products do
    primary :id, Int32, auto_increment: true
    varchar :name
    lock_version :version
    timestamp :deleted_at, null: true
  end

  table :parted_products do
    primary :id, Int32, auto_increment: true
    varchar :name
    lock_version :version
  end

  table :product_parts do
    primary :id, Int32, auto_increment: true
    integer :parted_product_id
  end
end

# Define our test class using Active Record
class Product
  include CQL::ActiveRecord::Model(Int32)
  include CQL::ActiveRecord::OptimisticLocking

  db_context OPTIMISTIC_LOCKING_TEST_SCHEMA, :products

  property id : Int32?
  property name : String
  property price : Float64
  property stock : Int32
  property version : Int32
  property created_at : Time
  property updated_at : Time

  # Initialize method for creating new instances
  def initialize(@name = "", @price = 0.0, @stock = 0, @version = 1, @created_at = Time.utc, @updated_at = Time.utc)
  end

  # Use optimistic locking on the version column
  optimistic_locking version_column: :version
end

# Define a test class for testing custom version column
class CustomProduct < Product
  # Simply reuse the same version_column to test the API
  optimistic_locking version_column: :version
end

class Int64Product
  include CQL::ActiveRecord::Model(Int64)
  include CQL::ActiveRecord::OptimisticLocking

  db_context OPTIMISTIC_LOCKING_TEST_SCHEMA, :int64_products

  property id : Int64?
  property name : String
  property price : Float64
  property stock : Int32
  property version : Int32
  property created_at : Time
  property updated_at : Time

  def initialize(@name = "", @price = 0.0, @stock = 0, @version = 1, @created_at = Time.utc, @updated_at = Time.utc)
  end

  optimistic_locking version_column: :version
end

# Optimistic locking together with soft deletes
class SoftLockedProduct
  include CQL::ActiveRecord::Model(Int32)
  include CQL::ActiveRecord::SoftDeletable
  include CQL::ActiveRecord::OptimisticLocking

  db_context OPTIMISTIC_LOCKING_TEST_SCHEMA, :soft_products

  property name : String
  property version : Int32

  def initialize(@name = "", @version = 1)
  end

  optimistic_locking version_column: :version
end

class ProductPart
  include CQL::ActiveRecord::Model(Int32)
  db_context OPTIMISTIC_LOCKING_TEST_SCHEMA, :product_parts

  property parted_product_id : Int32 = 0
end

# Optimistic locking together with a `dependent:` association
class PartedProduct
  include CQL::ActiveRecord::Model(Int32)
  include CQL::ActiveRecord::OptimisticLocking
  db_context OPTIMISTIC_LOCKING_TEST_SCHEMA, :parted_products

  property name : String = ""
  property version : Int32 = 1

  has_many :parts, ProductPart, foreign_key: :parted_product_id, dependent: :delete_all
  optimistic_locking version_column: :version
end

module CQL::ActiveRecord::OptimisticLockingSpec
  describe "Optimistic Locking" do
    before_each do
      OPTIMISTIC_LOCKING_TEST_SCHEMA.build
      # Clean up table before each test
      Product.delete_all
      Int64Product.delete_all
    end

    after_all do
      # Clean up after all tests
      OPTIMISTIC_LOCKING_TEST_SCHEMA.products.drop!
      OPTIMISTIC_LOCKING_TEST_SCHEMA.int64_products.drop!
    end

    it "puts its version back when the update's transaction rolls back, so the next update is not refused" do
      product = Product.new("Lamp", 10.0, 1)
      product.save!
      expect_raises(Exception, "boom") { OPTIMISTIC_LOCKING_TEST_SCHEMA.transaction { product.name = "Desk"; product.update!; raise "boom" } }
      product.version.should eq 1
      product.update!
      Product.find!(product.id!).name.should eq "Desk"
    end

    it "saves a soft-deleted record under the lock, updating its row" do
      product = SoftLockedProduct.create!(name: "Old")
      product.delete!.should be_true

      product.name = "New"
      product.save.should be_true

      product.version.should eq(2)
      SoftLockedProduct.count_with_deleted.should eq(1)
      SoftLockedProduct.with_deleted.find!(product.id!).name.should eq("New")
    end

    it "should create a product with version 1" do
      product = Product.create!(name: "Test Product", price: 10.0, stock: 5)
      product.version.should eq(1)
    end

    it "should increment version when updating" do
      product = Product.create!(name: "Test Product", price: 10.0, stock: 5)
      original_version = product.version

      product.price = 15.0
      product.update!

      product.version.should eq(original_version + 1)
    end

    it "should detect concurrent modifications" do
      product = Product.create!(name: "Test Product", price: 10.0, stock: 5)

      # Simulate a concurrent update by directly modifying the database
      OPTIMISTIC_LOCKING_TEST_SCHEMA.exec_query do |conn|
        conn.exec(
          "UPDATE products SET price = ?, stock = ?, version = ? WHERE id = ?",
          args: [20.0, 10, 2, product.id]
        )
      end

      # Attempt to update with stale version should fail
      product.name = "Updated Product"
      expect_raises(CQL::OptimisticLockError) do
        product.update!
      end
    end

    it "should succeed after reload" do
      product = Product.create!(name: "Test Product", price: 10.0, stock: 5)
      product_id = product.id.not_nil!

      # Simulate a concurrent update
      OPTIMISTIC_LOCKING_TEST_SCHEMA.exec_query do |conn|
        conn.exec(
          "UPDATE products SET price = ?, stock = ?, version = ? WHERE id = ?",
          args: [20.0, 10, 2, product_id]
        )
      end

      # First attempt fails
      product.name = "Updated Product"
      expect_raises(CQL::OptimisticLockError) do
        product.update!
      end

      # After reload, update should succeed
      # Get a fresh copy of the product to avoid any stale state
      product = Product.find!(product_id)
      product.name = "Updated Product"
      product.update!

      # Version should be incremented
      product.version.should eq(3)

      # Verify in database that both changes were applied
      reloaded = Product.find!(product_id)
      reloaded.name.should eq("Updated Product")
      reloaded.price.should eq(20.0)
      reloaded.stock.should eq(10)
      reloaded.version.should eq(3)
    end

    it "should handle multiple updates without conflict" do
      product = Product.create!(name: "Test Product", price: 10.0, stock: 5)

      # Sequential updates without conflict
      3.times do |_|
        product.price += 5.0
        product.update!
      end

      product.version.should eq(4)  # Initial 1 + 3 updates
      product.price.should eq(25.0) # 10 + (5*3)
    end

    it "should use correct version column when specified" do
      custom_product = CustomProduct.create!(name: "Custom", price: 15.0)
      custom_product.version.should eq(1)

      custom_product.price = 20.0
      custom_product.update!

      custom_product.version.should eq(2)
    end

    context "when deleting" do
      it "raises on a stale copy and keeps the row the other copy saved" do
        copy_a = Product.create!(name: "Original")
        copy_b = Product.find!(copy_a.id!)
        copy_a.name = "Changed by A"
        copy_a.update!

        expect_raises(CQL::OptimisticLockError) { copy_b.delete! }

        Product.find!(copy_a.id!).name.should eq("Changed by A")
        copy_b.destroyed?.should be_false
        copy_b.id.should eq(copy_a.id)
      end

      it "deletes a current record and returns true" do
        product = Product.create!(name: "Current")
        product_id = product.id!

        product.delete!.should be_true
        Product.find?(product_id).should be_nil
      end

      it "raises when another process already deleted the row" do
        product = Product.create!(name: "Gone")
        Product.delete!(product.id!)

        expect_raises(CQL::OptimisticLockError) { product.delete! }
      end

      it "keeps the dependent rows when a stale delete raises" do
        copy_a = PartedProduct.create!(name: "Original")
        ProductPart.create!(parted_product_id: copy_a.id!)
        copy_b = PartedProduct.find!(copy_a.id!)
        copy_a.name = "Changed by A"
        copy_a.update!

        expect_raises(CQL::OptimisticLockError) { copy_b.delete! }

        ProductPart.where(parted_product_id: copy_a.id!).count.should eq(1)
      end
    end

    context "with an Int64 primary key" do
      it "should increment the Int32 version on the record and in the database" do
        product = Int64Product.create!(name: "Test Product")
        product_id = product.id.not_nil!

        product.price = 15.0
        product.update!

        product.version.should eq(2)
        Int64Product.find!(product_id).version.should eq(2)
      end

      it "should detect a stale copy" do
        product = Int64Product.create!(name: "Test Product")
        product_id = product.id.not_nil!

        OPTIMISTIC_LOCKING_TEST_SCHEMA.exec_query do |conn|
          conn.exec("UPDATE int64_products SET version = version + 1 WHERE id = ?", args: [product_id])
        end

        product.name = "Updated Product"
        expect_raises(CQL::OptimisticLockError) do
          product.update!
        end
      end
    end
  end
end
