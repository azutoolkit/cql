require "../../../spec_helper"

EagerLoadingDB = CQL::Schema.define(
  :EagerLoadingDB,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://spec/support/db/eager_loading_spec.db") do
  table :users do
    primary :id
    varchar :name
    timestamps
  end

  table :posts do
    primary :id
    varchar :title
    integer :user_id
    timestamps
  end

  table :comments do
    primary :id
    varchar :content
    integer :user_id
    integer :post_id
    timestamps
  end
end

struct EagerUser
  include CQL::ActiveRecord::Model(Int32)

  db_context schema: EagerLoadingDB, table: :users

  property name : String
  has_many :posts, EagerPost, foreign_key: :user_id
  has_many :comments, EagerComment, foreign_key: :user_id
end

struct EagerPost
  include CQL::ActiveRecord::Model(Int32)

  db_context schema: EagerLoadingDB, table: :posts

  property title : String

  belongs_to :user, EagerUser, foreign_key: :user_id
  has_many :comments, EagerComment, foreign_key: :post_id
end

struct EagerComment
  include CQL::ActiveRecord::Model(Int32)

  db_context schema: EagerLoadingDB, table: :comments

  property content : String
  belongs_to :user, EagerUser, foreign_key: :user_id
  belongs_to :post, EagerPost, foreign_key: :post_id
end

module CQL::ActiveRecord::Relations
  describe EagerLoading do
    # Setup test data
    before_each do
      EagerLoadingDB.users.drop!
      EagerLoadingDB.posts.drop!
      EagerLoadingDB.comments.drop!

      EagerLoadingDB.users.create!
      EagerLoadingDB.posts.create!
      EagerLoadingDB.comments.create!

      # Create test data
      user1 = EagerUser.create!(name: "John")
      user2 = EagerUser.create!(name: "Jane")

      post1 = EagerPost.create!(title: "Post 1", user_id: user1.id!)
      post2 = EagerPost.create!(title: "Post 2", user_id: user1.id!)
      post3 = EagerPost.create!(title: "Post 3", user_id: user2.id!)

      EagerComment.create!(content: "Comment 1", user_id: user1.id!, post_id: post1.id!)
      EagerComment.create!(content: "Comment 2", user_id: user1.id!, post_id: post2.id!)
      EagerComment.create!(content: "Comment 3", user_id: user2.id!, post_id: post3.id!)
    end

    describe "#preload" do
      it "loads associations in separate queries" do
        users = EagerUser.all
        EagerLoading.preload(users, [:posts, :comments])

        # Verify associations are loaded
        users.each do |user|
          expect(user.association_loaded?(:posts)).to be_true
          expect(user.association_loaded?(:comments)).to be_true
        end

        # Verify correct associations
        user1 = users.find { |u| u.name == "John" }.not_nil!
        expect(user1.posts.size).to eq(2)
        expect(user1.comments.size).to eq(2)

        user2 = users.find { |u| u.name == "Jane" }.not_nil!
        expect(user2.posts.size).to eq(1)
        expect(user2.comments.size).to eq(1)
      end

      it "handles empty collections" do
        users = [] of EagerUser
        EagerLoading.preload(users, [:posts, :comments])
        expect(users).to be_empty
      end

      it "handles non-existent associations" do
        users = EagerUser.all
        expect {
          EagerLoading.preload(users, [:non_existent])
        }.to raise_error(KeyError)
      end
    end

    describe "#includes" do
      it "loads associations using JOIN queries" do
        users = EagerUser.all
        EagerLoading.includes(users, [:posts, :comments])

        # Verify associations are loaded
        users.each do |user|
          expect(user.association_loaded?(:posts)).to be_true
          expect(user.association_loaded?(:comments)).to be_true
        end

        # Verify correct associations
        user1 = users.find { |u| u.name == "John" }.not_nil!
        expect(user1.posts.size).to eq(2)
        expect(user1.comments.size).to eq(2)

        user2 = users.find { |u| u.name == "Jane" }.not_nil!
        expect(user2.posts.size).to eq(1)
        expect(user2.comments.size).to eq(1)
      end

      it "handles empty collections" do
        users = [] of EagerUser
        EagerLoading.includes(users, [:posts, :comments])
        expect(users).to be_empty
      end

      it "handles non-existent associations" do
        users = EagerUser.all
        expect {
          EagerLoading.includes(users, [:non_existent])
        }.to raise_error(KeyError)
      end
    end

    describe "Collection methods" do
      it "supports preload on collections" do
        user = EagerUser.find_by(name: "John").not_nil!
        user.posts.preload([:comments])

        # Verify associations are loaded
        user.posts.each do |post|
          expect(post.association_loaded?(:comments)).to be_true
        end

        # Verify correct associations
        expect(user.posts.first!.comments.size).to eq(1)
      end

      it "supports includes on collections" do
        user = EagerUser.find_by(name: "John").not_nil!
        user.posts.includes([:comments])

        # Verify associations are loaded
        user.posts.each do |post|
          expect(post.association_loaded?(:comments)).to be_true
        end

        # Verify correct associations
        expect(user.posts.first!.comments.size).to eq(1)
      end

      it "checks if associations are eager loaded" do
        user = EagerUser.find_by(name: "John").not_nil!
        user.posts.preload([:comments])

        expect(user.posts.eager_loaded?(:comments)).to be_true
        expect(user.posts.eager_loaded?(:non_existent)).to be_false
      end
    end
  end
end
