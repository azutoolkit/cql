require "../../support/postgres_spec_support"

private def resolve(config = ::CQL::Postgres::Configuration.new, env = ::CQL::Postgres::Environment::Development, app = "blog", environ = {} of String => String)
  ::CQL::Postgres::Database::URLResolver.resolve(config, env, app, environ)
end

describe ::CQL::Postgres::Database::URLResolver do
  it "falls back to the app/env convention" do
    resolve.should eq "postgres://localhost/blog_development"
    resolve(env: ::CQL::Postgres::Environment::Test).should eq "postgres://localhost/blog_test"
  end

  it "prefers explicit config, then DATABASE_URL, then parts" do
    config = ::CQL::Postgres::Configuration.new
    environ = {"DATABASE_URL" => "postgres://env/db", "CQL_DB_NAME" => "parts"}
    resolve(config, environ: environ).should eq "postgres://env/db"

    config.url = "postgres://config/db"
    resolve(config, environ: environ).should eq "postgres://config/db"

    resolve(environ: {"CQL_DB_NAME" => "parts"}).should eq "postgres://localhost/parts"
  end

  it "builds a URL from PG* variables" do
    environ = {"PGHOST" => "db.internal", "PGPORT" => "5433", "PGUSER" => "app", "PGPASSWORD" => "p@ss", "PGDATABASE" => "shop"}
    resolve(environ: environ).should eq "postgres://app:p%40ss@db.internal:5433/shop"
  end

  it "appends pool settings without overriding the URL" do
    config = ::CQL::Postgres::Configuration.new
    config.url = "postgres://localhost/app"
    config.pool_size = 12
    config.checkout_timeout = 2.5
    url = resolve(config)
    url.should contain "max_pool_size=12"
    url.should contain "max_idle_pool_size=12"
    url.should contain "checkout_timeout=2.5"

    config.url = "postgres://localhost/app?max_pool_size=3"
    resolve(config).should contain "max_pool_size=3"
    resolve(config).should_not contain "max_pool_size=12"
  end

  it "redacts passwords" do
    ::CQL::Postgres::Database::URLResolver.redact("postgres://app:secret@localhost/db").should eq "postgres://app:***@localhost/db"
    ::CQL::Postgres::Database::URLResolver.redact("postgres://localhost/db").should eq "postgres://localhost/db"
  end

  it "derives an app slug from the program name" do
    ::CQL::Postgres::Database::URLResolver.app_slug("/usr/bin/My-App").should eq "my_app"
    ::CQL::Postgres::Database::URLResolver.app_slug("blog.cr").should eq "blog"
  end
end
