require "../../../src/cql"
require "../models/*"
require "../../utilities/beautify"

include Beautify

# =============================================================================
# STATISTICS AND REPORTING DEMO
# =============================================================================

module BlogDemo
  module Demos
    def self.statistics_and_reporting(schema)
      section("Statistics & Reporting")

      sub_header("Blog Statistics")
      configuration_block("Content Statistics", {
        "Total Users"      => User.count,
        "Total Posts"      => Post.count,
        "Published Posts"  => Post.where(published: true).count,
        "Draft Posts"      => Post.where(published: false).count,
        "Total Comments"   => Comment.count,
        "Total Categories" => Category.count,
      })

      sub_header("Content Analysis")
      avg_word_count = Post.all.sum(&.word_count) / Post.count
      most_active_author = User.all.max_by(&.posts.count)
      database_operation("Average post word count", avg_word_count.to_s)
      database_operation("Most active author", most_active_author.username)

      # Raw SQL example
      sub_header("Raw SQL Query")
      info("Executing advanced SQL query for user post counts...")
      sql_snippet(<<-SQL)
        SELECT users.username, COUNT(posts.id) as post_count
        FROM users
        LEFT JOIN posts ON users.id = posts.user_id
        GROUP BY users.id, users.username
        ORDER BY post_count DESC
      SQL

      schema.exec(<<-SQL)
        SELECT users.username, COUNT(posts.id) as post_count
        FROM users
        LEFT JOIN posts ON users.id = posts.user_id
        GROUP BY users.id, users.username
        ORDER BY post_count DESC
      SQL

      success("Raw SQL query executed successfully")
    end
  end
end
