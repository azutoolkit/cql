# Define a test schema for spec use
UserDB = CQL::Schema.define(
  :data,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://spec/support/db/user_db.db") do
  table :users do
    primary :id, Int32
    column :name, String, null: true
    column :email, String
    column :age, Int32
    column :password, String
    timestamps
  end

  table :posts do
    primary :id, Int32
    column :title, String
    column :body, String
    column :user_id, Int32, null: true
  end

  table :profiles do
    primary :id, Int32
    column :bio, String
    column :avatar_url, String
    column :profile_owner_id, Int32, null: true
  end

  table :profile_owners do
    primary :id, Int32
    column :name, String
    column :email, String
    column :age, Int32
    column :password, String
    column :password_confirmation, String
    timestamps
  end

  table :movies do
    primary :id, Int32
    column :title, String
    column :release_year, Int32
  end

  table :actors do
    primary :id, Int32
    column :name, String
    column :age, Int32
  end

  table :movies_actor do
    primary :id, Int32
    column :movie_id, Int32
    column :actor_id, Int32
  end
end
