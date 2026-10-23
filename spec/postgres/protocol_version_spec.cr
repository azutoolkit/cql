require "../spec_helper"
require "../../src/postgres"

private alias Version = CQL::Postgres::ProtocolVersion

describe CQL::Postgres::ProtocolVersion do
  it "parses the supported versions and `latest`" do
    Version.parse("3.0").should eq Version::V3_0
    Version.parse("3.2").should eq Version::V3_2
    Version.parse("latest").should eq Version::LATEST
    expect_raises(ArgumentError, /unsupported protocol version "3.1"/) { Version.parse("3.1") }
    expect_raises(ArgumentError) { Version.parse("4.0") }
  end

  it "orders versions and prints them" do
    (Version::V3_0 < Version::V3_2).should be_true
    Version::V3_2.to_s.should eq "3.2"
  end

  it "knows the number sent in the startup packet" do
    Version::V3_0.code.should eq 196608
    Version::V3_2.code.should eq 196610
  end

  it "lowers its minor version to what the server offers, never raises it" do
    Version::V3_2.negotiated(0).should eq Version::V3_0
    Version::V3_0.negotiated(2).should eq Version::V3_0
  end

  it "reads the offer as a minor version (PostgreSQL 18) or as a whole version number (earlier servers)" do
    Version::V3_2.negotiated(1).should eq Version::V3_0
    Version::V3_2.negotiated(196608).should eq Version::V3_0
    Version::V3_2.negotiated(196610).should eq Version::V3_2
  end

  it "allows a 4..256 byte cancel key from 3.2 on and exactly 4 bytes before" do
    Version::V3_0.valid_secret_key?(Bytes.new(4)).should be_true
    Version::V3_0.valid_secret_key?(Bytes.new(8)).should be_false
    Version::V3_2.valid_secret_key?(Bytes.new(32)).should be_true
    Version::V3_2.valid_secret_key?(Bytes.new(256)).should be_true
    Version::V3_2.valid_secret_key?(Bytes.new(257)).should be_false
    Version::V3_2.valid_secret_key?(Bytes.new(3)).should be_false
  end
end
