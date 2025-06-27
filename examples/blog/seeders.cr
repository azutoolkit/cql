require "../../src/cql"
require "./models/*"
require "../utilities/beautify"

include Beautify

# =============================================================================
# SEEDING DATA
# =============================================================================

module BlogDemo
  module Seeders
    def self.seed_data
      section("Seeding Database")

      # Clear existing data to avoid duplicates
      Comment.delete_all
      Post.delete_all
      Category.delete_all
      User.delete_all

      # Create users
      john = User.create!(
        username: "john_doe",
        email: "john@example.com",
        first_name: "John",
        last_name: "Doe"
      )

      jane = User.create!(
        username: "jane_smith",
        email: "jane@example.com",
        first_name: "Jane",
        last_name: "Smith"
      )

      success("Created #{User.count} users")
      database_operation("Users", "john_doe, jane_smith")

      # Create categories
      tech_cat = Category.create!(name: "Technology", slug: "tech")
      lifestyle_cat = Category.create!(name: "Lifestyle", slug: "lifestyle")

      success("Created #{Category.count} categories")
      database_operation("Categories", "Technology, Lifestyle")

      # Create posts
      crystal_post = Post.create!(
        title: "Getting Started with Crystal",
        content: "Crystal is a powerful programming language that combines the performance of compiled languages with the expressiveness of Ruby. In this post, we'll explore the basics of Crystal programming and why it's becoming popular among developers.",
        user_id: john.id.not_nil!,
        category_id: tech_cat.id,
        published: true,
        views_count: 150_i64
      )

      productivity_post = Post.create!(
        title: "10 Productivity Tips for Developers",
        content: "Working efficiently as a developer requires good habits and tools. Here are ten proven strategies to boost your productivity and maintain work-life balance.",
        user_id: jane.id.not_nil!,
        category_id: lifestyle_cat.id,
        published: true,
        views_count: 89_i64
      )

      draft_post = Post.create!(
        title: "Advanced Crystal Patterns",
        content: "This is a draft post about advanced Crystal patterns...",
        user_id: john.id.not_nil!,
        category_id: tech_cat.id,
        published: false,
        views_count: 0_i64
      )

      success("Created #{Post.count} posts (#{Post.where(published: true).count} published)")
      bullet_point("Getting Started with Crystal - 150 views")
      bullet_point("10 Productivity Tips for Developers - 89 views")
      bullet_point("Advanced Crystal Patterns (draft)")

      # Create comments
      Comment.create!(
        content: "Great introduction to Crystal! Very helpful for beginners.",
        post_id: crystal_post.id.not_nil!,
        user_id: jane.id.not_nil!
      )

      Comment.create!(
        content: "These productivity tips are excellent. Thanks for sharing!",
        post_id: productivity_post.id.not_nil!,
        user_id: john.id.not_nil!
      )

      success("Created #{Comment.count} comments")

      configuration_block("Seeded Data Summary", {
        "Users"      => User.count,
        "Categories" => Category.count,
        "Posts"      => Post.count,
        "Comments"   => Comment.count,
      })

      {
        users:      {john: john, jane: jane},
        categories: {tech: tech_cat, lifestyle: lifestyle_cat},
        posts:      {crystal: crystal_post, productivity: productivity_post, draft: draft_post},
      }
    end
  end
end
