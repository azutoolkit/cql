require "spec"
require "../../src/query_cache"

describe CQL::QueryCache do
  before_each do
    CQL::QueryCache.clear
    CQL::QueryCache.enabled = true
    CQL::QueryCache.default_ttl = 1.hour
  end

  it "caches block results and returns cached value on hit" do
    result1 = CQL::QueryCache.cache("test", {"a" => "1"}) { "foo" }
    result2 = CQL::QueryCache.cache("test", {"a" => "1"}) { "bar" }
    result1.should eq "foo"
    result2.should eq "foo"
  end

  it "returns new value for different params" do
    a = CQL::QueryCache.cache("test", {"x" => "1"}) { "A" }
    b = CQL::QueryCache.cache("test", {"x" => "2"}) { "B" }
    a.should eq "A"
    b.should eq "B"
  end

  it "expires cache after TTL" do
    CQL::QueryCache.cache("ttl", {} of String => String, 1.second) { "short" }
    CQL::QueryCache.has_key?("ttl:#{Digest::MD5.hexdigest(({} of String => String).to_json)}").should be_true
    sleep(2.seconds)
    CQL::QueryCache.has_key?("ttl:#{Digest::MD5.hexdigest(({} of String => String).to_json)}").should be_false
  end

  it "clears cache and reports size" do
    CQL::QueryCache.cache("a", {"x" => "1"}) { "one" }
    CQL::QueryCache.cache("b", {"x" => "2"}) { "two" }
    CQL::QueryCache.size.should eq 2
    CQL::QueryCache.clear
    CQL::QueryCache.size.should eq 0
  end

  it "serializes and deserializes simple values" do
    CQL::QueryCache.cache("str", {} of String => String) { "hello" }.should eq "hello"
    CQL::QueryCache.cache("num", {} of String => String) { 42 }.should eq 42
  end

  it "can disable and enable cache" do
    CQL::QueryCache.enabled = false
    CQL::QueryCache.cache("x", {} of String => String) { "a" }.should eq "a"
    CQL::QueryCache.cache("x", {} of String => String) { "b" }.should eq "b"
    CQL::QueryCache.enabled = true
    CQL::QueryCache.cache("x", {} of String => String) { "c" }.should eq "c"
    CQL::QueryCache.cache("x", {} of String => String) { "d" }.should eq "c"
  end
end
