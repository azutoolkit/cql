require "../../../spec_helper"

module CQL::ActiveRecord::Relations
  describe EagerLoading do
    # Setup test data
    before_each do
      TestDB.users.drop!
      TestDB.posts.drop!
      TestDB.comments.drop!

      TestDB.users.create!
      TestDB.posts.create!
      TestDB.comments.create!

      # Create test data
      user1 = User.create(name: "John")
      user2 = User.create(name: "Jane")

      post1 = Post.create(title: "Post 1", user_id: user1.id!)
      post2 = Post.create(title: "Post 2", user_id: user1.id!)
      post3 = Post.create(title: "Post 3", user_id: user2.id!)

      Comment.create(content: "Comment 1", user_id: user1.id!, post_id: post1.id!)
      Comment.create(content: "Comment 2", user_id: user1.id!, post_id: post2.id!)
      Comment.create(content: "Comment 3", user_id: user2.id!, post_id: post3.id!)
    end

    describe "#preload" do
      it "loads associations in separate queries" do
        users = User.all
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
        users = [] of User
        EagerLoading.preload(users, [:posts, :comments])
        expect(users).to be_empty
      end

      it "handles non-existent associations" do
        users = User.all
        expect {
          EagerLoading.preload(users, [:non_existent])
        }.to raise_error(KeyError)
      end
    end

    describe "#includes" do
      it "loads associations using JOIN queries" do
        users = User.all
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
        users = [] of User
        EagerLoading.includes(users, [:posts, :comments])
        expect(users).to be_empty
      end

      it "handles non-existent associations" do
        users = User.all
        expect {
          EagerLoading.includes(users, [:non_existent])
        }.to raise_error(KeyError)
      end
    end

    describe "Collection methods" do
      it "supports preload on collections" do
        user = User.find_by(name: "John").not_nil!
        user.posts.preload([:comments])

        # Verify associations are loaded
        user.posts.each do |post|
          expect(post.association_loaded?(:comments)).to be_true
        end

        # Verify correct associations
        expect(user.posts.first!.comments.size).to eq(1)
      end

      it "supports includes on collections" do
        user = User.find_by(name: "John").not_nil!
        user.posts.includes([:comments])

        # Verify associations are loaded
        user.posts.each do |post|
          expect(post.association_loaded?(:comments)).to be_true
        end

        # Verify correct associations
        expect(user.posts.first!.comments.size).to eq(1)
      end

      it "checks if associations are eager loaded" do
        user = User.find_by(name: "John").not_nil!
        user.posts.preload([:comments])

        expect(user.posts.eager_loaded?(:comments)).to be_true
        expect(user.posts.eager_loaded?(:non_existent)).to be_false
      end
    end
  end
end
