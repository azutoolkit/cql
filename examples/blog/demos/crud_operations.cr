require "../../../src/cql"
require "../models/*"

# =============================================================================
# CRUD OPERATIONS DEMO
# =============================================================================

module BlogDemo
  module Demos
    def self.crud_operations(data)
      puts "\n🔧 CRUD Operations Demo"

      # READ operations
      puts "\nREAD Operations:"
      puts "  Total users: #{User.count}"
      puts "  Published posts: #{Post.where(published: true).count}"
      puts "  Total comments: #{Comment.count}"

      # FIND operations
      admin_user = User.find_by(username: "john_doe")
      if admin_user
        puts "  Found user: #{admin_user.full_name}"
      end

      # Fix the potential QueryBuilder issue by ensuring we get a Post instance
      most_viewed_posts = Post
        .where(published: true)
        .order(views_count: :desc)
        .limit(1)
        .all(Post)

      if most_viewed_posts.size > 0
        most_viewed = most_viewed_posts.first
        puts "  Most viewed post: #{most_viewed.title} (#{most_viewed.views_count} views)"
      end

      # UPDATE operations
      puts "\nUPDATE Operations:"
      crystal_post = data[:posts][:crystal]
      crystal_post.views_count += 25
      crystal_post.save!
      puts "  Updated post views: #{crystal_post.views_count}"

      # CREATE operations
      puts "\nCREATE Operations:"
      new_comment = Comment.create!(
        content: "Looking forward to more Crystal content!",
        post_id: crystal_post.id.not_nil!,
        user_id: data[:users][:jane].id.not_nil!
      )
      puts "  Created new comment: #{new_comment.content[0..30]}..."
    end
  end
end
