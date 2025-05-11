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
end

# Define our test class using Active Record
class Product
  include CQL::ActiveRecord::Model(Int32)
  include CQL::ActiveRecord::OptimisticLocking

  db_context OPTIMISTIC_LOCKING_TEST_SCHEMA, :products

  property id : Int32?
  property name : String = ""
  property price : Float64 = 0.0
  property stock : Int32 = 0
  property version : Int32 = 1
  property created_at : Time = Time.utc
  property updated_at : Time = Time.utc

  # Use optimistic locking on the version column
  optimistic_locking version_column: :version
end

# Define a test class for testing custom version column
class CustomProduct < Product
  # Simply reuse the same version_column to test the API
  optimistic_locking version_column: :version
end

module CQL::ActiveRecord::OptimisticLockingSpec
  describe "Optimistic Locking" do
    before_each do
      OPTIMISTIC_LOCKING_TEST_SCHEMA.build
      # Clean up table before each test
      Product.delete_all
    end

    after_all do
      # Clean up after all tests
      OPTIMISTIC_LOCKING_TEST_SCHEMA.products.drop!
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
  end
end
