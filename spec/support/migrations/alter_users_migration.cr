class AlterUsersMigration < CQL::Migration(20250705001402)
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
