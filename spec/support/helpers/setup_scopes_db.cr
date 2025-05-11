def setup_scopes_db
  # Setup the database
  MyApp::DB.scopes_posts.drop!
  MyApp::DB.scopes_posts.create!

  # Let's add some sample data
  posts = [
    ScopesPost.new(
      title: "No title",
      body: "No body",
      category: "fictional",
      published: false,
      created_at: Time.utc(1999, 1, 1)
    ),
    ScopesPost.new(
      title: "Getting Started with Crystal",
      body: "Crystal is a programming language...",
      category: "Programming",
      published: true,
      created_at: Time.utc(2023, 1, 1)
    ),
    ScopesPost.new("Why I love Crystal", "Crystal combines speed and readability...", "Programming", true, Time.utc(2023, 3, 15)),
    ScopesPost.new("Crystal ORM Tutorial", "Learn how to use CQL for database access...", "Tutorial", true, Time.utc(2023, 5, 20)),
    ScopesPost.new("Building APIs with Crystal", "Creating RESTful APIs is easy...", "Tutorial", false, Time.utc(2023, 6, 10)),
    ScopesPost.new("Draft: Future of Crystal", "Some thoughts on where Crystal is headed...", "Opinion", false, Time.utc(2023, 7, 1)),
  ]

  # Insert the sample posts
  posts.each(&.save)
end
