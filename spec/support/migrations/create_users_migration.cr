class CreateUsersMigration < CQL::Migration(20250705001401)
  def up
    schema.users.create!
  end

  def down
    schema.users.drop!
  end
end
