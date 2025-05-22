require "../spec_helper"

# Create test models
class Customer
  include CQL::ActiveRecord::Model(Int32)
  db_context EagerDB, :customers

  property id : Int32?
  property name : String
  property email : String

  has_many :orders, Order, foreign_key: :customer_id
  has_one :address, Address
end

class Address
  include CQL::ActiveRecord::Model(Int32)
  db_context EagerDB, :addresses

  property id : Int32?
  property customer_id : Int32
  property street : String
  property city : String
  property country : String

  belongs_to :customer, Customer, foreign_key: :customer_id
end

class Category
  include CQL::ActiveRecord::Model(Int32)
  db_context EagerDB, :categories

  property id : Int32?
  property name : String

  has_many :products, Product, foreign_key: :category_id
end

class Product
  include CQL::ActiveRecord::Model(Int32)
  db_context EagerDB, :products

  property id : Int32?
  property category_id : Int32
  property name : String
  property price : Float64

  belongs_to :category, Category, foreign_key: :category_id
  many_to_many :product_tags, ProductTag, join_through: ProductsProductTags
end

class Order
  include CQL::ActiveRecord::Model(Int32)
  db_context EagerDB, :orders

  property id : Int32?
  property customer_id : Int32
  property status : String
  property total_amount : Float64

  belongs_to :customer, Customer, foreign_key: :customer_id
  has_many :order_items, OrderItem, foreign_key: :order_id
end

class OrderItem
  include CQL::ActiveRecord::Model(Int32)
  db_context EagerDB, :order_items

  property id : Int32?
  property order_id : Int32
  property product_id : Int32
  property quantity : Int32
  property unit_price : Float64

  belongs_to :order, Order, foreign_key: :order_id
  belongs_to :product, Product, foreign_key: :product_id
end

class ProductTag
  include CQL::ActiveRecord::Model(Int32)
  db_context EagerDB, :product_tags

  property id : Int32?
  property name : String

  many_to_many :products, Product, join_through: ProductsProductTags
end

class ProductsProductTags
  include CQL::ActiveRecord::Model(Int32)
  db_context EagerDB, :products_product_tags

  property id : Int32?
  property product_id : Int32
  property product_tag_id : Int32

  belongs_to :product, Product, foreign_key: :product_id
  belongs_to :product_tag, ProductTag, foreign_key: :product_tag_id
end

module CQL
  module ActiveRecord
    describe "ActiveRecord::Query#includes" do
      before_all do
        EagerDB.customers.create!
        EagerDB.addresses.create!
        EagerDB.categories.create!
        EagerDB.products.create!
        EagerDB.orders.create!
        EagerDB.order_items.create!
        EagerDB.product_tags.create!
        EagerDB.products_product_tags.create!
      end

      after_all do
        EagerDB.products_product_tags.drop!
        EagerDB.product_tags.drop!
        EagerDB.order_items.drop!
        EagerDB.orders.drop!
        EagerDB.products.drop!
        EagerDB.categories.drop!
        EagerDB.addresses.drop!
        EagerDB.customers.drop!
      end

      it "eager loads has_many associations" do
        # Create test data
        customer1 = Customer.create!(name: "John Doe", email: "john@example.com")
        customer2 = Customer.create!(name: "Jane Smith", email: "jane@example.com")
        order1 = Order.create!(customer_id: customer1.id.not_nil!, status: "pending", total_amount: 100.0)
        order2 = Order.create!(customer_id: customer1.id.not_nil!, status: "completed", total_amount: 200.0)
        order3 = Order.create!(customer_id: customer2.id.not_nil!, status: "pending", total_amount: 150.0)

        # Test eager loading
        customers = Customer.includes(:orders).all
        customers.size.should eq(2)

        # Verify orders are loaded
        customer1_orders = customers.find { |c| c.id == customer1.id.not_nil! }.not_nil!.orders
        customer1_orders.size.should eq(2)
        customer1_orders.map(&.status).sort.should eq(["completed", "pending"])

        customer2_orders = customers.find { |c| c.id == customer2.id.not_nil! }.not_nil!.orders
        customer2_orders.size.should eq(1)
        customer2_orders.first.status.should eq("pending")
      end

      it "eager loads belongs_to associations" do
        # Create test data
        category1 = Category.create!(name: "Electronics")
        category2 = Category.create!(name: "Books")
        product1 = Product.create!(category_id: category1.id.not_nil!, name: "Laptop", price: 999.99)
        product2 = Product.create!(category_id: category1.id.not_nil!, name: "Phone", price: 499.99)
        product3 = Product.create!(category_id: category2.id.not_nil!, name: "Novel", price: 19.99)

        # Test eager loading
        products = Product.includes(:category).all
        products.size.should eq(3)

        # Verify categories are loaded
        products.find { |p| p.id == product1.id.not_nil! }.not_nil!.category.not_nil!.name.should eq("Electronics")
        products.find { |p| p.id == product2.id.not_nil! }.not_nil!.category.not_nil!.name.should eq("Electronics")
        products.find { |p| p.id == product3.id.not_nil! }.not_nil!.category.not_nil!.name.should eq("Books")
      end

      it "eager loads has_one associations" do
        # Create test data
        customer1 = Customer.create!(name: "John Doe", email: "john@example.com")
        customer2 = Customer.create!(name: "Jane Smith", email: "jane@example.com")
        address1 = Address.create!(customer_id: customer1.id.not_nil!, street: "123 Main St", city: "New York", country: "USA")
        address2 = Address.create!(customer_id: customer2.id.not_nil!, street: "456 Oak Ave", city: "Los Angeles", country: "USA")

        # Test eager loading
        customers = Customer.includes(:address).all
        customers.size.should eq(2)

        # Verify addresses are loaded
        customers.find { |c| c.id == customer1.id.not_nil! }.not_nil!.address.not_nil!.city.should eq("New York")
        customers.find { |c| c.id == customer2.id.not_nil! }.not_nil!.address.not_nil!.city.should eq("Los Angeles")
      end

      it "eager loads has_and_belongs_to_many associations" do
        # Create test data
        product1 = Product.create!(name: "Laptop", price: 999.99)
        product2 = Product.create!(name: "Phone", price: 499.99)
        tag1 = ProductTag.create!(name: "Electronics")
        tag2 = ProductTag.create!(name: "Gadgets")
        tag3 = ProductTag.create!(name: "Premium")

        # Create join table records
        ProductsProductTags.create!(product_id: product1.id.not_nil!, product_tag_id: tag1.id.not_nil!)
        ProductsProductTags.create!(product_id: product1.id.not_nil!, product_tag_id: tag3.id.not_nil!)
        ProductsProductTags.create!(product_id: product2.id.not_nil!, product_tag_id: tag1.id.not_nil!)
        ProductsProductTags.create!(product_id: product2.id.not_nil!, product_tag_id: tag2.id.not_nil!)

        # Test eager loading
        products = Product
          .includes(:product_tags)
          .where(id: [product1.id.not_nil!, product2.id.not_nil!])
          .all(Product)

        products.size.should eq(2)

        # Verify tags are loaded
        product1_tags = products.first.product_tags
        product1_tags.size.should eq(2)
        product1_tags.map(&.name).sort.should eq(["Electronics", "Premium"])

        product2_tags = products.last.product_tags
        product2_tags.size.should eq(2)
        product2_tags.map(&.name).sort.should eq(["Electronics", "Gadgets"])
      end

      it "handles nil associations correctly" do
        # Create test data
        customer = Customer.create!(name: "John Doe", email: "john@example.com")
        order1 = Order.create!(customer_id: customer.id.not_nil!, status: "pending", total_amount: 100.0)
        order2 = Order.create!(customer_id: nil, status: "pending", total_amount: 200.0)

        # Test eager loading
        orders = Order.includes(:customer).all
        orders.size.should eq(2)

        # Verify associations
        orders.find { |o| o.id == order1.id.not_nil! }.not_nil!.customer.not_nil!.name.should eq("John Doe")
        orders.find { |o| o.id == order2.id.not_nil! }.not_nil!.customer.should be_nil
      end

      it "can eager load multiple associations" do
        # Create test data
        customer = Customer.create!(name: "John Doe", email: "john@example.com")
        address = Address.create!(customer_id: customer.id.not_nil!, street: "123 Main St", city: "New York", country: "USA")
        order1 = Order.create!(customer_id: customer.id.not_nil!, status: "pending", total_amount: 100.0)
        order2 = Order.create!(customer_id: customer.id.not_nil!, status: "completed", total_amount: 200.0)

        # Test eager loading multiple associations
        customers = Customer.includes(:orders, :address).all
        customers.size.should eq(1)

        # Verify all associations are loaded
        customer = customers.first
        customer.orders.size.should eq(2)
        customer.orders.map(&.status).sort.should eq(["completed", "pending"])
        customer.address.not_nil!.city.should eq("New York")
      end
    end
  end
end
