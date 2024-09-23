class CreateUsersMigration < Cql::Migration(123456789)
  def up
    schema.users.create!
  end

  def down
    schema.users.drop!
  end
end
