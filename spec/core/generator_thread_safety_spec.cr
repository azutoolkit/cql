require "../spec_helper"

describe "Generator Thread Safety" do
  it "handles concurrent query generation without corruption" do
    schema = Northwind
    results = Channel({String, Array(DB::Any)}).new(100)

    # Spawn 50 fibers building queries concurrently
    50.times do |i|
      spawn do
        query = schema.query
          .from(:users)
          .where(id: i)
          .to_sql
        results.send(query)
      end
    end

    # Collect results
    collected = [] of {String, Array(DB::Any)}
    50.times do
      collected << results.receive
    end

    # Verify each query has exactly one parameter (the id)
    collected.each do |sql, params|
      params.size.should eq(1)
      sql.should contain("WHERE")
    end
  end

  it "handles concurrent inserts without param corruption" do
    schema = Northwind
    results = Channel({String, Array(DB::Any)}).new(100)

    20.times do |i|
      spawn do
        insert = schema.insert
          .into(:users)
          .values(name: "User#{i}", email: "user#{i}@test.com", age: 20 + i)
          .to_sql
        results.send(insert)
      end
    end

    collected = [] of {String, Array(DB::Any)}
    20.times do
      collected << results.receive
    end

    # Each insert should have exactly 3 params
    collected.each do |sql, params|
      params.size.should eq(3)
    end
  end

  it "handles concurrent updates without param corruption" do
    schema = Northwind
    results = Channel({String, Array(DB::Any)}).new(100)

    20.times do |i|
      spawn do
        update = schema.update
          .table(:users)
          .set(name: "Updated#{i}")
          .where(id: i)
          .to_sql
        results.send(update)
      end
    end

    collected = [] of {String, Array(DB::Any)}
    20.times do
      collected << results.receive
    end

    # Each update should have exactly 2 params (set value + where id)
    collected.each do |sql, params|
      params.size.should eq(2)
    end
  end

  it "handles concurrent deletes without param corruption" do
    schema = Northwind
    results = Channel({String, Array(DB::Any)}).new(100)

    20.times do |i|
      spawn do
        delete = schema.delete
          .from(:users)
          .where(id: i)
          .to_sql
        results.send(delete)
      end
    end

    collected = [] of {String, Array(DB::Any)}
    20.times do
      collected << results.receive
    end

    # Each delete should have exactly 1 param (where id)
    collected.each do |sql, params|
      params.size.should eq(1)
    end
  end

  it "new_generator returns fresh instance each time" do
    schema = Northwind

    gen1 = schema.new_generator
    gen2 = schema.new_generator

    # They should be different objects
    gen1.object_id.should_not eq(gen2.object_id)

    # Modifying one should not affect the other
    query1 = schema.query.from(:users).where(id: 1).to_sql(gen1)
    query2 = schema.query.from(:users).where(id: 2).to_sql(gen2)

    query1[1].should eq([1] of DB::Any)
    query2[1].should eq([2] of DB::Any)
  end
end
