require "../../../src/cql"
require "../models/*"

# =============================================================================
# PERFORMANCE FEATURES DEMO
# =============================================================================

module BlogDemo
  module Demos
    def self.performance_features
      puts "\n⚡ Performance Features"

      # Batch processing
      puts "\nBatch Processing:"
      post_count = 0
      Post.find_each(batch_size: 2) do |_|
        post_count += 1
      end
      puts "  Processed #{post_count} posts in batches"

      # Pluck for efficient data extraction
      puts "\nEfficient Data Extraction:"
      post_titles = Post.where(published: true).pluck(:title, as: String)
      puts "  Post titles: #{post_titles.join(", ")}"

      user_emails = User.pluck(:email)
      puts "  User emails: #{user_emails.join(", ")}"
    end
  end
end
