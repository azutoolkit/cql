module CQL
  module JSONBConverter
    def self.from_rs(rs : DB::ResultSet) : JSON::Any
      pull_parser = rs.read(JSON::PullParser)
      JSON::Any.new(pull_parser)
    end

    def self.to_db(value : JSON::Any) : String
      value.to_json
    end
  end
end
