EagerDB = CQL::Schema.define(
  :eager_db,
  adapter: CQL::Adapter::Postgres,
  uri: "sqlite3://spec/support/db/eager_testing.db") do
  table :customers do
    primary :id, Int32
    column :name, String
    column :email, String
  end

  table :addresses do
    primary :id, Int32
    column :customer_id, Int32
    column :street, String
    column :city, String
    column :country, String
  end

  table :categories do
    primary :id, Int32
    column :name, String
  end

  table :products do
    primary :id, Int32
    column :category_id, Int32
    column :name, String
    column :price, Float64
  end

  table :orders do
    primary :id, Int32
    column :customer_id, Int32
    column :status, String
    column :total_amount, Float64
  end

  table :order_items do
    primary :id, Int32
    column :order_id, Int32
    column :product_id, Int32
    column :quantity, Int32
    column :unit_price, Float64
  end

  table :product_tags do
    primary :id, Int32
    column :name, String
  end

  table :products_product_tags do
    primary :id, Int32
    column :product_id, Int32
    column :product_tag_id, Int32
  end
end
