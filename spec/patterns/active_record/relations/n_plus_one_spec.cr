require "../../../spec_helper"

module CQL::ActiveRecord::Relations
  describe "N+1 Query Prevention" do
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

    describe "N+1 Query Detection" do
      it "detects N+1 queries in has_many associations" do
        # This should trigger N+1 queries
        users = User.all
        query_count = 0

        # Mock the query execution to count queries
        allow(TestDB).to receive(:query) do |sql|
          query_count += 1
          [] of DB::Any
        end

        users.each do |user|
          user.posts.each do |post|
            post.title
          end
        end

        # Should be 1 query for users + 1 query per user for posts
        expect(query_count).to eq(users.size + 1)
      end

      it "prevents N+1 queries with preload" do
        users = User.all
        query_count = 0

        # Mock the query execution to count queries
        allow(TestDB).to receive(:query) do |sql|
          query_count += 1
          [] of DB::Any
        end

        # Preload posts
        EagerLoading.preload(users, [:posts])

        users.each do |user|
          user.posts.each do |post|
            post.title
          end
        end

        # Should be 1 query for users + 1 query for all posts
        expect(query_count).to eq(2)
      end

      it "prevents N+1 queries with includes" do
        users = User.all
        query_count = 0

        # Mock the query execution to count queries
        allow(TestDB).to receive(:query) do |sql|
          query_count += 1
          [] of DB::Any
        end

        # Include posts
        EagerLoading.includes(users, [:posts])

        users.each do |user|
          user.posts.each do |post|
            post.title
          end
        end

        # Should be 1 query for users with posts
        expect(query_count).to eq(1)
      end
    end

    describe "Nested Associations" do
      it "detects N+1 queries in nested associations" do
        users = User.all
        query_count = 0

        # Mock the query execution to count queries
        allow(TestDB).to receive(:query) do |sql|
          query_count += 1
          [] of DB::Any
        end

        users.each do |user|
          user.posts.each do |post|
            post.comments.each do |comment|
              comment.content
            end
          end
        end

        # Should be 1 query for users + 1 query per user for posts + 1 query per post for comments
        expect(query_count).to eq(1 + users.size + users.sum { |u| u.posts.size })
      end

      it "prevents N+1 queries in nested associations with preload" do
        users = User.all
        query_count = 0

        # Mock the query execution to count queries
        allow(TestDB).to receive(:query) do |sql|
          query_count += 1
          [] of DB::Any
        end

        # Preload posts and comments
        EagerLoading.preload(users, [:posts])
        posts = users.flat_map(&.posts)
        EagerLoading.preload(posts, [:comments])

        users.each do |user|
          user.posts.each do |post|
            post.comments.each do |comment|
              comment.content
            end
          end
        end

        # Should be 1 query for users + 1 query for all posts + 1 query for all comments
        expect(query_count).to eq(3)
      end

      it "prevents N+1 queries in nested associations with includes" do
        users = User.all
        query_count = 0

        # Mock the query execution to count queries
        allow(TestDB).to receive(:query) do |sql|
          query_count += 1
          [] of DB::Any
        end

        # Include posts and comments
        EagerLoading.includes(users, [:posts, :comments])

        users.each do |user|
          user.posts.each do |post|
            post.comments.each do |comment|
              comment.content
            end
          end
        end

        # Should be 1 query for users with posts and comments
        expect(query_count).to eq(1)
      end
    end
  end
end
