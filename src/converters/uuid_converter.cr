module CQL
  # Converter for UUID type to handle serialization/deserialization
  # when storing UUIDs as TEXT in databases like SQLite
  # Internal text storage accepts both native PostgreSQL and text-backed UUIDs.
  module UUIDStorageConverter
    def self.from_rs(rs : DB::ResultSet) : String?
      rs.read(UUID | String | Nil).try(&.to_s)
    end
  end

  module UUIDConverter
    def self.from_rs(rs : DB::ResultSet) : UUID
      value = rs.read(UUID | String)
      value.is_a?(UUID) ? value : UUID.new(value)
    end

    def self.to_db(value : UUID) : String
      value.to_s
    end

    def self.to_db(value : Nil) : Nil
      nil
    end
  end
end
