require "../../../src/cql"
require "../models/*"
require "../../utilities/beautify"

include Beautify

# =============================================================================
# PERFORMANCE FEATURES DEMO
# =============================================================================

module BlogDemo
  module Demos
    def self.performance_features
      section("Performance Features")

      # Batch processing
      sub_header("Batch Processing")
      post_count = 0
      Post.find_each(batch_size: 2) do |_|
        post_count += 1
      end
      performance("Processed #{post_count} posts in batches of 2")

      # Pluck for efficient data extraction
      sub_header("Efficient Data Extraction")
      post_titles = Post.where(published: true).pluck(:title, as: String)
      database_operation("Post titles", post_titles.join(", "))

      user_emails = User.pluck(:email)
      database_operation("User emails", user_emails.join(", "))
    end
  end
end
