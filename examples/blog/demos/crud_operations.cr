require "../../../src/cql"
require "../models/*"
require "../../utilities/beautify"

include Beautify

# =============================================================================
# CRUD OPERATIONS DEMO
# =============================================================================

module BlogDemo
  module Demos
    def self.crud_operations(data)
      section("CRUD Operations Demo")

      # READ operations
      sub_header("READ Operations")
      database_operation("Total users", "#{User.count}")
      database_operation("Published posts", "#{Post.where(published: true).count}")
      database_operation("Total comments", "#{Comment.count}")

      # FIND operations
      admin_user = User.find_by(username: "john_doe")
      if admin_user
        success("Found user: #{admin_user.full_name}")
      end

      # Fix the potential QueryBuilder issue by ensuring we get a Post instance
      most_viewed_posts = Post
        .where(published: true)
        .order(views_count: :desc)
        .limit(1)
        .all(Post)

      if most_viewed_posts.size > 0
        most_viewed = most_viewed_posts.first
        info("Most viewed post: #{most_viewed.title} (#{most_viewed.views_count} views)")
      end

      # UPDATE operations
      sub_header("UPDATE Operations")
      crystal_post = data[:posts][:crystal]
      old_views = crystal_post.views_count
      crystal_post.views_count += 25
      crystal_post.save!
      performance("Updated post views: #{old_views} → #{crystal_post.views_count}")

      # CREATE operations
      sub_header("CREATE Operations")
      new_comment = Comment.create!(
        content: "Looking forward to more Crystal content!",
        post_id: crystal_post.id.not_nil!,
        user_id: data[:users][:jane].id.not_nil!
      )
      success("Created new comment: #{new_comment.content[0..30]}...")
      bullet_point("Author: #{data[:users][:jane].username}")
      bullet_point("Post: #{crystal_post.title}")
    end
  end
end
