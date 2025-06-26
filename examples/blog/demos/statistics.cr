require "../../../src/cql"
require "../models/*"

# =============================================================================
# STATISTICS AND REPORTING DEMO
# =============================================================================

module BlogDemo
  module Demos
    def self.statistics_and_reporting(schema)
      puts "\n📊 Statistics & Reporting"

      puts "\nBlog Statistics:"
      puts "  Total Users: #{User.count}"
      puts "  Total Posts: #{Post.count}"
      puts "  Published Posts: #{Post.where(published: true).count}"
      puts "  Draft Posts: #{Post.where(published: false).count}"
      puts "  Total Comments: #{Comment.count}"
      puts "  Total Categories: #{Category.count}"

      puts "\nContent Analysis:"
      puts "  Average post word count: #{Post.all.sum(&.word_count) / Post.count}"
      most_active_author = User.all.max_by(&.posts.count)
      puts "  Most active author: #{most_active_author.username}"

      # Raw SQL example
      puts "\nRaw SQL Query:"
      schema.exec(<<-SQL)
        SELECT users.username, COUNT(posts.id) as post_count
        FROM users
        LEFT JOIN posts ON users.id = posts.user_id
        GROUP BY users.id, users.username
        ORDER BY post_count DESC
      SQL
    end
  end
end
