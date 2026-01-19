module CQL
  # Converter for UUID type to handle serialization/deserialization
  # when storing UUIDs as TEXT in databases like SQLite
  module UUIDConverter
    def self.from_rs(rs : DB::ResultSet) : UUID
      UUID.new(rs.read(String))
    end

    def self.to_db(value : UUID) : String
      value.to_s
    end

    def self.to_db(value : Nil) : Nil
      nil
    end
  end
end
