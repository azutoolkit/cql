class CreateUsersMigration < Cql::Migration
  self.version = 123456789_i64

  def up
    schema.users.create!
  end

  def down
    schema.users.drop!
  end
end
