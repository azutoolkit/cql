require "spec"

describe CQL::Cache::Cache do
  before_each do
    CQL::Cache::Cache.clear
    CQL::Cache::Cache.enabled = true
    CQL::Cache::Cache.default_ttl = 1.hour
  end

  it "caches block results and returns cached value on hit" do
    result1 = CQL::Cache::Cache.cache("test", {"a" => "1"}) { "foo" }
    result2 = CQL::Cache::Cache.cache("test", {"a" => "1"}) { "bar" }
    result1.should eq "foo"
    result2.should eq "foo"
  end

  it "returns new value for different params" do
    a = CQL::Cache::Cache.cache("test", {"x" => "1"}) { "A" }
    b = CQL::Cache::Cache.cache("test", {"x" => "2"}) { "B" }
    a.should eq "A"
    b.should eq "B"
  end

  it "expires cache after TTL" do
    CQL::Cache::Cache.cache("ttl", {} of String => String, 1.second) { "short" }
    CQL::Cache::Cache.has_key?("ttl:#{Digest::MD5.hexdigest(({} of String => String).to_json)}").should be_true
    sleep(2.seconds)
    CQL::Cache::Cache.has_key?("ttl:#{Digest::MD5.hexdigest(({} of String => String).to_json)}").should be_false
  end

  it "clears cache and reports size" do
    CQL::Cache::Cache.cache("a", {"x" => "1"}) { "one" }
    CQL::Cache::Cache.cache("b", {"x" => "2"}) { "two" }
    CQL::Cache::Cache.size.should eq 2
    CQL::Cache::Cache.clear
    CQL::Cache::Cache.size.should eq 0
  end

  it "serializes and deserializes simple values" do
    CQL::Cache::Cache.cache("str", {} of String => String) { "hello" }.should eq "hello"
    CQL::Cache::Cache.cache("num", {} of String => String) { 42 }.should eq 42
  end

  it "can disable and enable cache" do
    CQL::Cache::Cache.enabled = false
    CQL::Cache::Cache.cache("x", {} of String => String) { "a" }.should eq "a"
    CQL::Cache::Cache.cache("x", {} of String => String) { "b" }.should eq "b"
    CQL::Cache::Cache.enabled = true
    CQL::Cache::Cache.cache("x", {} of String => String) { "c" }.should eq "c"
    CQL::Cache::Cache.cache("x", {} of String => String) { "d" }.should eq "c"
  end
end
