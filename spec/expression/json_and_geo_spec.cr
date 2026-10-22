require "../spec_helper"

DOCS = CQL::Schema.define(:json_docs, adapter: CQL::Adapter::SQLite, uri: spec_sqlite_uri("json_docs.db")) do
  table :documents do
    primary :id, Int32
    column :name, String
    column :data, JSON::Any
    column :location, String, null: true
  end
end

describe "JSON predicates" do
  pg = -> { Expression::Generator.new(CQL::Adapter::Postgres) }
  mysql = -> { Expression::Generator.new(CQL::Adapter::MySql) }
  base = -> { DOCS.query.from(:documents).select(:name) }

  it "compares an extracted value on PostgreSQL (path bound as text[])" do
    sql, params = base.call.where { documents.data.json_eq(["profile", "country"], "US") }.to_sql(pg.call)

    sql.should eq("SELECT documents.name FROM documents WHERE documents.data #>> $1::text[] = $2")
    params.should eq(["{profile,country}", "US"] of DB::Any)
  end

  it "uses JSON_EXTRACT on MySQL and json_extract on SQLite with a bound path" do
    sql, params = base.call.where { documents.data.json_eq("theme", "dark") }.to_sql(mysql.call)
    sql.should end_with("WHERE JSON_UNQUOTE(JSON_EXTRACT(documents.data, ?)) = ?")
    params.should eq(["$.theme", "dark"] of DB::Any)

    sql, params = base.call.where { documents.data.json_eq(["tags", 0], "a") }.to_sql
    sql.should end_with("WHERE CAST(json_extract(documents.data, ?) AS TEXT) = ?")
    params.should eq(["$.tags[0]", "a"] of DB::Any)
  end

  it "compares numbers and booleans as text" do
    base.call.where { documents.data.json_eq("age", 30) }.to_sql[1].should eq(["$.age", "30"] of DB::Any)
    base.call.where { documents.data.json_eq("ok", true) }.to_sql(pg.call)[1].should eq(["{ok}", "true"] of DB::Any)
  end

  it "tests containment with @> on PostgreSQL and JSON_CONTAINS on MySQL" do
    sql, params = base.call.where { documents.data.json_contains({role: "admin"}) }.to_sql(pg.call)
    sql.should end_with("WHERE documents.data @> $1::jsonb")
    params.should eq([%({"role":"admin"})] of DB::Any)

    base.call.where { documents.data.json_contains({role: "admin"}) }.to_sql(mysql.call)[0].should end_with("WHERE JSON_CONTAINS(documents.data, ?)")
  end

  it "rejects containment on SQLite with a clear error" do
    expect_raises(CQL::DialectError, /SQLite does not support JSON containment/) do
      base.call.where { documents.data.json_contains({role: "admin"}) }.to_sql
    end
  end

  it "rejects path segments that are not plain keys or indexes" do
    expect_raises(ArgumentError, /Invalid JSON path segment/) { base.call.where { documents.data.json_eq("a'] OR 1=1 --", "x") } }
    expect_raises(ArgumentError, /Invalid JSON path segment/) { base.call.where { documents.data.json_eq([""], "x") } }
  end

  it "keeps parameter order with other conditions" do
    sql, params = base.call.where(name: "n").where { documents.data.json_eq("k", "v") }.to_sql(pg.call)

    params.should eq(["n", "{k}", "v"] of DB::Any)
    sql.should end_with("(documents.name = $1) AND (documents.data #>> $2::text[] = $3)")
  end

  describe "executing against SQLite" do
    before_each do
      DOCS.documents.create!
      {"ada" => %({"profile":{"country":"US"},"age":30,"tags":["x","y"]}), "grace" => %({"profile":{"country":"UK"},"age":40,"tags":["y"]})}.each do |name, json|
        DOCS.insert.into(:documents).values(name: name, data: JSON.parse(json)).commit
      end
    end
    after_each { DOCS.documents.drop! }

    it "filters on nested values, numbers and array elements" do
      base.call.where { documents.data.json_eq(["profile", "country"], "US") }.all(as: String).should eq(["ada"])
      base.call.where { documents.data.json_eq("age", 40) }.all(as: String).should eq(["grace"])
      base.call.where { documents.data.json_eq(["tags", 0], "y") }.all(as: String).should eq(["grace"])
    end
  end
end

describe "Geospatial distance filter" do
  pg = -> { Expression::Generator.new(CQL::Adapter::Postgres) }
  base = -> { DOCS.query.from(:documents).select(:name) }

  it "uses ST_DWithin on geography for PostgreSQL and CockroachDB" do
    sql, params = base.call.where { documents.location.within_distance(-122.4, 37.8, 500) }.to_sql(pg.call)

    sql.should eq("SELECT documents.name FROM documents WHERE ST_DWithin(documents.location::geography, ST_SetSRID(ST_MakePoint($1::float8, $2::float8), 4326)::geography, $3::float8)")
    params.should eq([-122.4, 37.8, 500.0] of DB::Any)
    base.call.where { documents.location.within_distance(1.0, 2.0, 3) }.to_sql(Expression::Generator.new(CQL::Adapter::CockroachDB))[0].should contain("ST_DWithin")
  end

  it "uses ST_Distance_Sphere on MySQL" do
    sql, params = base.call.where { documents.location.within_distance(-122.4, 37.8, 500) }.to_sql(Expression::Generator.new(CQL::Adapter::MySql))

    sql.should end_with("WHERE ST_Distance_Sphere(documents.location, ST_GeomFromText(CONCAT('POINT(', ?, ' ', ?, ')'), 4326, 'axis-order=long-lat')) <= ?")
    params.should eq([-122.4, 37.8, 500.0] of DB::Any)
  end

  it "is rejected on SQLite with a clear error" do
    expect_raises(CQL::DialectError, /SQLite does not support geospatial distance filters/) do
      base.call.where { documents.location.within_distance(1.0, 2.0, 3) }.to_sql
    end
  end

  it "rejects a negative distance" do
    expect_raises(ArgumentError, /distance must not be negative/) { base.call.where { documents.location.within_distance(1.0, 2.0, -1) } }
  end
end

describe "JSON booleans and geo input validation" do
  base = -> { DOCS.query.from(:documents).select(:name) }

  describe "booleans on SQLite (json_extract yields 1/0)" do
    before_each do
      DOCS.documents.create!
      DOCS.insert.into(:documents).values(name: "on", data: JSON.parse(%({"ok":true,"no":false}))).commit
    end
    after_each { DOCS.documents.drop! }

    it "matches true and false" do
      base.call.where { documents.data.json_eq("ok", true) }.all(as: String).should eq(["on"])
      base.call.where { documents.data.json_eq("no", false) }.all(as: String).should eq(["on"])
      base.call.where { documents.data.json_eq("ok", false) }.all(as: String).should be_empty
    end
  end

  it "keeps 'true'/'false' text for the other dialects" do
    base.call.where { documents.data.json_eq("ok", true) }.to_sql(Expression::Generator.new(CQL::Adapter::Postgres))[1].should eq(["{ok}", "true"] of DB::Any)
    base.call.where { documents.data.json_eq("ok", false) }.to_sql(Expression::Generator.new(CQL::Adapter::MySql))[1].should eq(["$.ok", "false"] of DB::Any)
  end

  it "rejects impossible coordinates and distances" do
    expect_raises(ArgumentError, /longitude must be between -180 and 180/) { base.call.where { documents.location.within_distance(181.0, 0.0, 1) } }
    expect_raises(ArgumentError, /latitude must be between -90 and 90/) { base.call.where { documents.location.within_distance(0.0, -91.0, 1) } }
    expect_raises(ArgumentError, /distance must be finite/) { base.call.where { documents.location.within_distance(0.0, 0.0, Float64::INFINITY) } }
    expect_raises(ArgumentError, /longitude must be between/) { base.call.where { documents.location.within_distance(Float64::NAN, 0.0, 1) } }
  end

  it "builds the MySQL point with explicit long-lat axis order" do
    sql, params = base.call.where { documents.location.within_distance(-122.4, 37.8, 500) }.to_sql(Expression::Generator.new(CQL::Adapter::MySql))

    sql.should end_with("WHERE ST_Distance_Sphere(documents.location, ST_GeomFromText(CONCAT('POINT(', ?, ' ', ?, ')'), 4326, 'axis-order=long-lat')) <= ?")
    params.should eq([-122.4, 37.8, 500.0] of DB::Any)
  end
end
