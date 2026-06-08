# Define a test schema for spec use
UserDB = CQL::Schema.define(
  :data,
  adapter: CQL::Adapter::SQLite,
  uri: spec_sqlite_uri("user_db.db")) do
  table :users do
    primary :id, Int32
    column :name, String, null: true
    column :email, String
    column :age, Int32
    column :password, String
    timestamp :created_at, null: true
    timestamp :updated_at, null: true
  end

  table :posts do
    primary :id, Int32
    column :title, String
    column :body, String
    column :user_id, Int32, null: true
    foreign_key [:user_id], references: :users, references_columns: [:id]
  end

  table :profiles do
    primary :id, Int32
    column :bio, String
    column :avatar_url, String
    column :profile_owner_id, Int32, null: true
    foreign_key [:profile_owner_id], references: :users, references_columns: [:id]
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
    timestamps
  end

  table :actors do
    primary :id, Int32
    column :name, String
    column :age, Int32
    timestamps
  end

  table :movies_actor do
    primary :id, Int32
    column :movie_id, Int32
    column :actor_id, Int32
    timestamps
    foreign_key [:movie_id], references: :movies, references_columns: [:id]
    foreign_key [:actor_id], references: :actors, references_columns: [:id]
  end

  table :roles do
    primary :id, Int32
    column :name, String
    column :description, String, null: true
    timestamps
  end

  table :user_roles do
    primary :id, Int32
    column :user_id, Int32
    column :role_id, Int32
    timestamps
    foreign_key [:user_id], references: :users, references_columns: [:id]
    foreign_key [:role_id], references: :roles, references_columns: [:id]
  end
end
