require "../../../src/cql"
require "../models/*"
require "../../utilities/beautify"

include Beautify

# =============================================================================
# RELATIONSHIPS DEMO
# =============================================================================

module BlogDemo
  module Demos
    def self.relationships(data)
      section("Relationships Demo")

      sub_header("Relationship Queries")

      # User -> Posts relationship
      john_user = User.find_by(username: "john_doe")
      if john_user
        john_posts = john_user.posts.where(published: true).all(Post)
        info("John's published posts: #{john_posts.size}")

        john_posts.each do |local_post|
          bullet_point(local_post.title)
        end
      end

      # Post -> Comments relationship
      crystal_post = data[:posts][:crystal]

      sub_header("Post Comments")
      crystal_post.comments.each do |comment|
        author_name = comment.user ? comment.user.not_nil!.username : "Anonymous"
        bullet_point("#{author_name}: #{comment.content[0..50]}...")
      end

      # Category -> Posts relationship
      tech_cat = data[:categories][:tech]
      tech_posts = tech_cat.posts.where(published: true)
      info("Tech category posts: #{tech_posts.count}")
    end
  end
end
