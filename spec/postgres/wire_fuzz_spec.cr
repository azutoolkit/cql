require "../spec_helper"
require "../../src/postgres"

describe "bounded PostgreSQL backend payload fuzzing" do
  it "rejects trailing bytes and malformed COPY format vectors" do
    [{'Z', Bytes['I'.ord.to_u8, 0]}, {'1', Bytes[0]}, {'G', Bytes[0, 0, 1]},
     {'H', Bytes[2, 0, 0]}, {'G', Bytes[0, 0, 1, 0, 2]}].each do |type, payload|
      expect_raises(CQL::Postgres::ProtocolError) do
        CQL::Postgres::Wire::Backend.decode(type, CQL::Postgres::Wire::Reader.new(payload))
      end
    end
  end

  it "either decodes or raises a protocol/authentication error for seeded arbitrary bytes" do
    random = Random.new(65_u64)
    types = "RSKZvTD CENAtGHdcI123ns".chars
    2_000.times do
      payload = Bytes.new(random.rand(0..128)) { random.rand(256).to_u8 }
      begin
        message = CQL::Postgres::Wire::Backend.decode(types.sample(random), CQL::Postgres::Wire::Reader.new(payload))
        message.each_field { |_| } if message.is_a?(CQL::Postgres::Wire::Backend::DataRow)
      rescue CQL::Postgres::ProtocolError | CQL::Postgres::AuthenticationError
        # Expected rejection; bounds/overflow errors and other exceptions fail the spec.
      end
    end
  end
end
