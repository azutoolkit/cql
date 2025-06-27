require "../../../src/cql"
require "../models/*"
require "../../utilities/beautify"

include Beautify

# =============================================================================
# COMPLEX QUERIES DEMO
# =============================================================================

module BlogDemo
  module Demos
    def self.complex_queries(schema)
      section("Complex Queries")

      # Simulate some potentially problematic queries for demonstration
      # This will create N+1 query patterns to show in the performance report

      # Queries with joins
      sub_header("Advanced Queries")

      published_posts = Post
        .where(published: true)
        .order(views_count: :desc)
        .all(Post)

      info("Published posts with authors: #{published_posts.size}")
      published_posts.each do |post|
        begin
          # This could potentially create N+1 queries - will be caught by performance monitor
          author = post.user
          author_name = author ? author.username : "Unknown"
          bullet_point("#{post.title} by #{author_name} (#{post.views_count} views)")
        rescue e
          bullet_point("#{post.title} by Unknown (#{post.views_count} views) [Error: #{e.message}]")
        end
      end

      # Simulate additional query patterns for performance monitoring
      status_indicator(:progress, "Simulating additional query patterns for performance monitoring...")

      # Multiple individual queries (potential N+1 pattern)
      User.all.each do |user|
        user.posts.count # This could create N+1 queries
      end

      # Some potentially slow queries for demonstration
      slow_query_start = Time.monotonic
      schema.exec(<<-SQL)
        SELECT u.username, p.title, c.content
        FROM users u
        LEFT JOIN posts p ON u.id = p.user_id
        LEFT JOIN comments c ON p.id = c.post_id
        WHERE p.published = 1
        ORDER BY p.views_count DESC, c.created_at DESC
      SQL
      slow_query_time = Time.monotonic - slow_query_start
      performance("Complex JOIN query executed in #{execution_time(slow_query_time)}")

      # Aggregation queries
      sub_header("Aggregation Queries")
      total_views = Post.where(published: true).sum(:views_count)
      avg_views = Post.where(published: true).avg(:views_count)
      database_operation("Total views", total_views.to_s)
      database_operation("Average views", "#{avg_views.try(&.round(1)) || 0}")

      # Posts by category
      sub_header("Posts by Category")
      Category.all.each do |cat|
        post_count = cat.posts.where(published: true).count
        bullet_point("#{cat.name}: #{post_count} posts")
      end

      # Users with post counts
      sub_header("Active Authors")
      User.all.each do |user|
        post_count = user.posts.where(published: true).count.get(Int64) || 0_i64
        if post_count > 0
          bullet_point("#{user.username}: #{post_count} posts")
        end
      end
    end
  end
end
