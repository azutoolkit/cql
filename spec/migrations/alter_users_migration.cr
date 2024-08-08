class AlterUsersMigration < Cql::Migration
  self.version = 987654321_i64

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
