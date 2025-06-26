require "../../../src/cql"
require "../models/*"

# =============================================================================
# COMPLEX QUERIES DEMO
# =============================================================================

module BlogDemo
  module Demos
    def self.complex_queries(schema)
      puts "\n🔍 Complex Queries"

      # Simulate some potentially problematic queries for demonstration
      # This will create N+1 query patterns to show in the performance report

      # Queries with joins
      puts "\nAdvanced Queries:"

      published_posts = Post
        .where(published: true)
        .order(views_count: :desc)
        .all(Post)

      puts "  Published posts with authors: #{published_posts.size}"
      published_posts.each do |post|
        begin
          # This could potentially create N+1 queries - will be caught by performance monitor
          author = post.user
          author_name = author ? author.username : "Unknown"
          puts "    - #{post.title} by #{author_name} (#{post.views_count} views)"
        rescue e
          puts "    - #{post.title} by Unknown (#{post.views_count} views) [Error: #{e.message}]"
        end
      end

      # Simulate additional query patterns for performance monitoring
      puts "\nSimulating additional query patterns for performance monitoring..."

      # Multiple individual queries (potential N+1 pattern)
      User.all.each do |user|
        user.posts.count # This could create N+1 queries
      end

      # Some potentially slow queries for demonstration
      slow_query_start = Time.monotonic
      complex_data = schema.exec(<<-SQL)
        SELECT u.username, p.title, c.content
        FROM users u
        LEFT JOIN posts p ON u.id = p.user_id
        LEFT JOIN comments c ON p.id = c.post_id
        WHERE p.published = 1
        ORDER BY p.views_count DESC, c.created_at DESC
      SQL
      slow_query_duration = Time.monotonic - slow_query_start

      # Aggregation queries
      puts "\nAggregation Queries:"
      total_views = Post.where(published: true).sum(:views_count)
      avg_views = Post.where(published: true).avg(:views_count)
      puts "  Total views: #{total_views}"
      puts "  Average views: #{avg_views.try(&.round(1)) || 0}"

      # Posts by category
      puts "\nPosts by Category:"
      Category.all.each do |cat|
        post_count = cat.posts.where(published: true).count
        puts "  #{cat.name}: #{post_count} posts"
      end

      # Users with post counts
      puts "\nActive Authors:"
      User.all.each do |user|
        post_count = user.posts.where(published: true).count.get(Int64) || 0_i64
        if post_count > 0
          puts "  #{user.username}: #{post_count} posts"
        end
      end
    end
  end
end
