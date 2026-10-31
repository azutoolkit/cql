require "../spec_helper"

module ExplicitBindingSpec
  Mapping = CQL::Schema.define(:bound_test, adapter: CQL::Adapter::SQLite) do
    table :bound_users do
      primary :id, Int64
      text :name
    end
    table :bound_documents do
      primary :id, Int64
      text :title
      lock_version :version
    end
    table :bound_tags do
      primary :id, Int64
      text :label
    end
    table :bound_taggings do
      primary :id, Int64
      bigint :user_id
      bigint :tag_id
    end
    table :bound_soft_users do
      primary :id, Int64
      text :name
      timestamp :deleted_at, null: true
    end
    table :bound_posts do
      primary :id, Int64
      bigint :user_id, null: true
      text :title
    end
  end

  PostMapping = CQL::Schema.define(:bound_posts_test, adapter: CQL::Adapter::SQLite) do
    table :bound_posts do
      primary :id, Int64
      bigint :user_id, null: true
      text :title
    end
  end

  class Reader
    include CQL::Executor

    def initialize(@schema : CQL::Schema)
    end

    def adapter : CQL::Adapter
      @schema.adapter
    end

    def exec_query(& : DB::Connection -> _)
      @schema.exec_query { |connection| yield connection }
    end
  end

  struct BoundDocument
    include CQL::Model(Int64)
    include CQL::ActiveRecord::DirtyTracking
    include CQL::ActiveRecord::OptimisticLocking
    db_context schema: Mapping, table: :bound_documents
    property title : String = ""
    property version : Int32 = 1
    optimistic_locking version_column: :version

    def initialize(@title = "")
    end
  end

  struct BoundTag
    include CQL::Model(Int64)
    db_context schema: Mapping, table: :bound_tags
    property label : String = ""

    def initialize(@label = "")
    end
  end

  struct BoundTagging
    include CQL::Model(Int64)
    db_context schema: Mapping, table: :bound_taggings
    property user_id : Int64 = 0
    property tag_id : Int64 = 0
  end

  class SoftUser
    include CQL::Model(Int64)
    include CQL::ActiveRecord::SoftDeletable
    db_context schema: Mapping, table: :bound_soft_users
    property name : String = ""
  end

  struct BoundUser
    include CQL::Model(Int64)
    db_context schema: Mapping, table: :bound_users
    property name : String = ""
    scope :named, ->(value : String) { where(name: value) }
    has_many :posts, ExplicitBindingSpec::BoundPost, foreign_key: :user_id, dependent: :destroy
    many_to_many :tags, ExplicitBindingSpec::BoundTag, join_through: ExplicitBindingSpec::BoundTagging,
      foreign_key: :user_id, association_foreign_key: :tag_id

    def initialize(@name = "")
    end
  end

  struct BoundPost
    include CQL::Model(Int64)
    db_context schema: PostMapping, table: :bound_posts
    property user_id : Int64?
    property title : String = ""
    belongs_to :user, ExplicitBindingSpec::BoundUser, foreign_key: :user_id, optional: true

    def initialize(@title = "", @user_id = nil)
    end
  end

  def self.with_databases(&)
    paths = Array.new(2) { File.join(Dir.tempdir, "cql_binding_#{Random::Secure.hex(8)}.db") }
    a = DB.open("sqlite3://#{paths[0]}")
    b = DB.open("sqlite3://#{paths[1]}")
    first_binding, second_binding = CQL::Binding.new(a), CQL::Binding.new(b)
    Mapping.bind(first_binding).build
    Mapping.bind(second_binding).build
    yield a, b, first_binding, second_binding
  ensure
    a.try(&.close)
    b.try(&.close)
    paths.try(&.each { |path| File.delete?(path) })
  end
end

describe "explicit model binding" do
  it "preserves struct saves, reloads, preloads, dependent deletes and caller ownership" do
    ExplicitBindingSpec.with_databases do |a, _, first_binding, second_binding|
      one = ExplicitBindingSpec::BoundUser.on(first_binding).create!(name: "one")
      two = ExplicitBindingSpec::BoundUser.on(second_binding).create!(name: "two")
      one.id.should eq(two.id)
      one.name = "changed"
      one.save!
      one.reload!
      one.name.should eq("changed")
      ExplicitBindingSpec::BoundUser.on(second_binding).find!(two.id!).name.should eq("two")
      post = one.posts.create(title: "post")
      post.id.should_not be_nil
      post.binding.should be(first_binding)
      loaded = ExplicitBindingSpec::BoundUser.on(first_binding).preload(:posts).first!
      loaded.posts_loaded?.should be_true
      loaded.posts.first.title.should eq("post")
      loaded.posts.first.user.not_nil!.name.should eq("changed")
      ExplicitBindingSpec::BoundUser.on(first_binding).query.delete_all.should eq(1)
      ExplicitBindingSpec::BoundPost.on(first_binding).count.should eq(0)
      ExplicitBindingSpec::BoundUser.on(second_binding).count.should eq(1)
      ExplicitBindingSpec::Mapping.bind(first_binding).close
      a.scalar("SELECT 1").should eq(1)
    end
  end

  it "shares an external transaction, creates nested savepoints and rejects closed transactions" do
    ExplicitBindingSpec.with_databases do |a, _, first_binding, _|
      binding = nil.as(CQL::Binding?)
      a.transaction do |tx|
        binding = CQL::Binding.new(tx)
        users = ExplicitBindingSpec::BoundUser.on(binding)
        users.create!(name: "outer")
        users.transaction do |inner|
          user = users.create!(name: "inner")
          user.posts.create(title: "inner child")
          ExplicitBindingSpec::BoundPost.on(binding).count.should eq(1)
          inner.rollback
        end
        users.count.should eq(1)
        ExplicitBindingSpec::BoundPost.on(binding).count.should eq(0)
        tx.rollback
      end
      ExplicitBindingSpec::BoundUser.on(first_binding).count.should eq(0)
      expect_raises(CQL::Error, "closed") { ExplicitBindingSpec::BoundUser.on(binding).count }
    end
  end

  it "copies declarations and never executes an unbound mapping" do
    ExplicitBindingSpec.with_databases do |_, _, first_binding, _|
      bound = ExplicitBindingSpec::Mapping.bind(first_binding)
      bound.bound_users.schema.should be(bound)
      bound.bound_users.columns[:name].should_not be(ExplicitBindingSpec::Mapping.bound_users.columns[:name])
      bound.bound_users.columns.delete(:name)
      ExplicitBindingSpec::Mapping.bound_users.columns.has_key?(:name).should be_true
      expect_raises(CQL::Error, "unbound") { ExplicitBindingSpec::BoundUser.count }
      incompatible = CQL::Schema.define(:incompatible, adapter: CQL::Adapter::Postgres) { }
      expect_raises(CQL::Error, "different adapters") { incompatible.bind(first_binding) }
    end
  end
end

describe "binding propagation" do
  it "keeps interleaved fibers, scopes, partial selects and relationship writes isolated" do
    ExplicitBindingSpec.with_databases do |_, _, first_binding, second_binding|
      done = Channel(Exception?).new(2)
      [first_binding, second_binding].each_with_index do |binding, index|
        spawn do
          users = ExplicitBindingSpec::BoundUser.on(binding)
          user = users.create!(name: "tenant #{index}")
          Fiber.yield
          users.named("tenant #{index}").count.should eq(1)
          users.select(:id).first!.id.should eq(user.id)
          user.posts.create(title: "child #{index}")
          Fiber.yield
          loaded = users.preload(:posts).first!
          loaded.posts.first.title.should eq("child #{index}")
          loaded.name = "updated #{index}"
          loaded.save!
          Fiber.yield
          loaded.reload!
          loaded.name.should eq("updated #{index}")
          done.send(nil)
        rescue ex
          done.send(ex)
        end
      end
      2.times { done.receive.try { |error| raise error } }
      first_users = ExplicitBindingSpec::BoundUser.on(first_binding)
      second_users = ExplicitBindingSpec::BoundUser.on(second_binding)
      expect_raises(CQL::Error, "different binding") { first_users.query.merge(second_users.query) }
      expect_raises(CQL::Error, "different binding") { first_users.first!.posts << second_users.first!.posts.first }
      first_users.query.delete_all.should eq(1)
      second_users.count.should eq(1)
    end
  end

  it "keeps generic executors readable and rejects writes without touching a default database" do
    ExplicitBindingSpec.with_databases do |_, _, first_binding, _|
      users = ExplicitBindingSpec::BoundUser.on(first_binding)
      users.create!(name: "read only")
      executor = ExplicitBindingSpec::Reader.new(ExplicitBindingSpec::Mapping.bind(first_binding))
      record = ExplicitBindingSpec::BoundUser.query.using(executor).first!
      record.name.should eq("read only")
      record.name = "blocked"
      expect_raises(CQL::Error, "Executor-only") { record.save! }
      expect_raises(CQL::Error, "Executor-only") { record.persistence_model.transaction { } }
      users.first!.name.should eq("read only")
    end
  end

  it "does not release borrowed connections after statement errors or schema close" do
    ExplicitBindingSpec.with_databases do |a, _, _, _|
      a.using_connection do |connection|
        schema = ExplicitBindingSpec::Mapping.bind(connection)
        expect_raises(SQLite3::Exception) { schema.exec("SELECT * FROM no_such_binding_table") }
        schema.close
        connection.scalar("SELECT 1").should eq(1)
        ExplicitBindingSpec::BoundUser.query.using(connection).count.should eq(0)
      end
      a.scalar("SELECT 1").should eq(1)
    end
  end
end

describe "bound soft deletion" do
  it "retains default filters and callback-aware class operations" do
    ExplicitBindingSpec.with_databases do |_, _, first_binding, second_binding|
      users = ExplicitBindingSpec::SoftUser.on(first_binding)
      other = ExplicitBindingSpec::SoftUser.on(second_binding)
      record = users.create!(name: "same")
      other.create!(name: "same").id.should eq(record.id)
      users.delete!(record.id!).should be_true
      users.count.should eq(0)
      users.with_deleted.count.should eq(1)
      users.with_deleted.delete_all.should eq(0)
      users.restore!(record.id!).should be_true
      users.count.should eq(1)
      users.delete_by!(name: "same").rows_affected.should eq(1)
      users.restore_all.should eq(1)
      users.force_delete!(record.id!).rows_affected.should eq(1)
      users.with_deleted.count.should eq(0)
      other.count.should eq(1)
    end
  end
end

describe "bound relationship writes" do
  it "keeps many-to-many preloads and batch has-many inserts on the owner binding" do
    ExplicitBindingSpec.with_databases do |_, _, first_binding, second_binding|
      first = ExplicitBindingSpec::BoundUser.on(first_binding).create!(name: "first")
      second = ExplicitBindingSpec::BoundUser.on(second_binding).create!(name: "second")
      first.tags.create(label: "first tag").id.should_not be_nil
      second.tags.create(label: "second tag").id.should_not be_nil
      first.insert_posts_all([{title: "bulk"}]).should eq(1)
      first.create_posts([ExplicitBindingSpec::BoundPost.new("built")]).first.id.should_not be_nil
      loaded = ExplicitBindingSpec::BoundUser.on(first_binding).preload(:tags, :posts).first!
      loaded.tags_loaded?.should be_true
      loaded.tags.first.label.should eq("first tag")
      loaded.tags.first.binding.should be(first_binding)
      loaded.posts.size.should eq(2)
      loaded.tags.delete_all.should eq(1)
      second.tags.reload.size.should eq(1)
      ExplicitBindingSpec::BoundPost.on(second_binding).count.should eq(0)
    end
  end
end

describe "bound tracked records" do
  it "keeps dirty state and optimistic versions current on struct saves" do
    ExplicitBindingSpec.with_databases do |_, _, first_binding, second_binding|
      documents = ExplicitBindingSpec::BoundDocument.on(first_binding)
      other = ExplicitBindingSpec::BoundDocument.on(second_binding)
      document = documents.build(title: "first")
      document.save!
      document.changed?.should be_false
      other.create!(title: "other").id.should eq(document.id)
      stale = documents.first!
      document.title = "updated"
      document.save!
      document.version.should eq(2)
      document.changed?.should be_false
      stale.title = "stale"
      expect_raises(CQL::OptimisticLockError) { stale.save! }
      other.first!.title.should eq("other")
      document.reload!
      document.title.should eq("updated")
    end
  end
end

describe "bound query composition" do
  it "preserves derived tables whose aliases match physical table names" do
    ExplicitBindingSpec.with_databases do |_, _, first_binding, _|
      users = ExplicitBindingSpec::BoundUser.on(first_binding)
      users.create!(name: "derived")
      source = ExplicitBindingSpec::Mapping.query.from(:bound_users).select(:name)
      query = ExplicitBindingSpec::Mapping.query.from(source, as: :bound_users)
      rebound = query.rebind(ExplicitBindingSpec::Mapping.bind(first_binding))
      rebound.query_tables["bound_users"][:table].columns.keys.should eq([:name])
      rebound.all(as: String).should eq(["derived"])
    end
  end

  it "rejects different bindings in set operands, CTEs and predicates before execution" do
    ExplicitBindingSpec.with_databases do |_, _, first_binding, second_binding|
      first = ExplicitBindingSpec::Mapping.bind(first_binding).query.from(:bound_users).select(:id)
      second = ExplicitBindingSpec::Mapping.bind(second_binding).query.from(:bound_users).select(:id)
      expect_raises(CQL::Error, "different bindings") { first.union(second).to_sql }
      expect_raises(CQL::Error, "different bindings") { first.clone.with(:other_users, second).to_sql }
      key = ExplicitBindingSpec::Mapping.bound_users.columns[:id].expression
      expect_raises(CQL::Error, "different bindings") { first.clone.where { key.in(second) }.to_sql }
    end
  end
end
