require "../../../src/cql"
require "../models/*"

# =============================================================================
# RELATIONSHIPS DEMO
# =============================================================================

module BlogDemo
  module Demos
    def self.relationships(data)
      puts "\n🔗 Relationships Demo"

      puts "\nRelationship Queries:"

      # User -> Posts relationship
      john_user = User.find_by(username: "john_doe")
      if john_user
        john_posts = john_user.posts.where(published: true).all(Post)
        puts "  John's published posts: #{john_posts.size}"

        john_posts.each do |local_post|
          puts "    - #{local_post.title}"
        end
      end

      # Post -> Comments relationship
      crystal_post = data[:posts][:crystal]

      crystal_post.comments.each do |comment|
        puts "comment: #{comment.content}"
        author_name = comment.user ? comment.user.not_nil!.username : "Anonymous"
        puts "    - #{author_name}: #{comment.content[0..50]}..."
      end

      # Category -> Posts relationship
      tech_cat = data[:categories][:tech]
      tech_posts = tech_cat.posts.where(published: true)
      puts "  Tech category posts: #{tech_posts.count}"
    end
  end
end
