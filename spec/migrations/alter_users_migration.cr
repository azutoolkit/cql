class AlterUsersMigration < Cql::Migration(987654321)
  def up
    schema.alter :users do
      add_column :phone, String
    end
  end

  def down
    schema.alter :users do
      drop_column :phone
    end
  end
end
