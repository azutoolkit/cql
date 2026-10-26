# Part 4: CRUD Operations

Build one script, `src/crud.cr`, that creates, queries, updates and deletes blog records. Each step adds to the script; run it after each step.

**You need:** the project from [Part 3](03-models-and-relationships.md).

## Step 1: Create records

```crystal
# src/crud.cr
require "./blog_engine"

# Start every run from empty tables; ON DELETE CASCADE removes the posts and comments
User.delete_all
Category.delete_all

# new + save: runs validations and callbacks; returns false when a callback halts it
alice = User.new(username: "alice", email: "alice@example.com", first_name: "Alice")
alice.save

# save!: raises instead of returning false
bob = User.new(username: "bob", email: "bob@example.com")
bob.save!

# create!: inserts exactly the columns you pass and returns the stored record
jane = User.create!(username: "jane", email: "jane@example.com", first_name: "Jane")

# Category.new runs initialize, which builds the slug; create! would skip it
tech, lifestyle, travel = ["Technology", "Lifestyle", "Travel"].map { |name| Category.new(name).tap(&.save!) }

intro = Post.create!(title: "Getting Started with Crystal", content: "Crystal is fast and friendly.",
  user_id: alice.id!, category_id: tech.id, published: true, views_count: 150_i64)
Post.create!(title: "Crystal Macros", content: "Macros run at compile time.",
  user_id: alice.id!, category_id: tech.id, published: true, views_count: 1200_i64)
Post.create!(title: "A Weekend in Lisbon", content: "Tram 28 and pastel de nata.",
  user_id: jane.id!, category_id: travel.id, published: true, views_count: 40_i64)
Post.create!(title: "Draft Ideas", content: "Not ready yet.", user_id: bob.id!, category_id: lifestyle.id)

Comment.create!(content: "Welcome to blogging!", post_id: intro.id!, user_id: bob.id)
Comment.create!(content: "Nice intro.", post_id: intro.id!) # anonymous

puts "Created #{User.count} users, #{Category.count} categories, #{Post.count} posts, #{Comment.count} comments"
```

```bash
crystal src/crud.cr
```

```text
Created 3 users, 3 categories, 4 posts, 2 comments
```

`save!` raises `CQL::RecordNotSaved` when a callback halts the save, and `CQL::ActiveRecord::Validations::ValidationError` for an invalid record. `create!` does not call your `initialize`, so pass every computed value, such as a slug, yourself; it also skips validations and callbacks.

## Step 2: Find records

Add to `src/crud.cr`:

```crystal
puts User.find(alice.id!).try(&.username)          # find: nil when missing
puts User.find_by(email: "jane@example.com").try(&.display_name)
puts Post.find_by(published: false, user_id: bob.id!).try(&.title)

begin
  User.find!(999_999)                                 # find!: raises when missing
rescue ex : DB::NoResultsError
  puts "find!: #{ex.message}"
end

latest = Post.where(published: true).order(created_at: :desc, id: :desc).limit(2).all
puts "Latest: #{latest.map(&.title)}"
puts "First user: #{User.first.try(&.username)}, last post: #{Post.last.try(&.title)}"
```

```text
...
alice
Jane
Draft Ideas
find!: No records found with id=999999
Latest: ["A Weekend in Lisbon", "Crystal Macros"]
First user: alice, last post: Draft Ideas
```

## Step 3: Filter with blocks and associations

Add to `src/crud.cr`:

```crystal
# Block conditions use the model's typed columns
popular = Post.where { views_count > 100 }.order(views_count: :desc).all
puts "Popular: #{popular.map(&.title)}"
extremes = Post.where { (views_count < 5) | (views_count > 1000) }.all
puts "Extremes: #{extremes.map(&.title)}"
recent = Post.where(published: true).where { created_at > 1.week.ago }.count
puts "Published this week: #{recent}"

# Through associations
puts "Alice wrote #{alice.posts.count} posts; the intro has #{intro.comments.all.size} comments"
puts "Tech posts: #{Post.where(category_id: tech.id!, published: true).count}"
by_alice = Post.query.joins(:user) { user.username == "alice" }.to_a
puts "Joined on author: #{by_alice.map(&.title)}"
```

```text
...
Popular: ["Crystal Macros", "Getting Started with Crystal"]
Extremes: ["Crystal Macros", "Draft Ideas"]
Published this week: 3
Alice wrote 2 posts; the intro has 2 comments
Tech posts: 2
Joined on author: ["Getting Started with Crystal", "Crystal Macros"]
```

Inside a block, bare names such as `views_count` or `user` are the model's columns and joined associations. A local variable with the same name wins, so keep no local called `user` in scope when you write `user.username`.

## Step 4: Paginate

Add to `src/crud.cr`:

```crystal
page, per_page = 2, 2
page_two = Post.where(published: true).order(created_at: :desc, id: :desc)
  .limit(per_page).offset((page - 1) * per_page).all
total = Post.where(published: true).count
puts "Page #{page} of #{(total / per_page.to_f).ceil.to_i}: #{page_two.map(&.title)}"
puts "Post.page(1, 3): #{Post.page(1, 3).size} posts"
```

```text
...
Page 2 of 2: ["Getting Started with Crystal"]
Post.page(1, 3): 3 posts
```

`Post.page(number, per_page)` neither filters nor orders, so the database picks the row order.

## Step 5: Count and aggregate

Add to `src/crud.cr`:

```crystal
published = Post.where(published: true)
puts "Views: total #{published.sum(:views_count)}, average #{published.avg(:views_count)}, " \
     "max #{published.max(:views_count)}, min #{published.min(:views_count)}"

# Posts per author in one GROUP BY query, instead of one count per user
counts = AppSchema.query
  .from(:posts)
  .select(:user_id, count: :id)
  .group(:user_id)
  .all(as: {Int64, Int64})
counts.sort_by { |_, total| -total }.each do |user_id, total|
  puts "  #{User.find!(user_id).display_name}: #{total} posts"
end
```

```text
...
Views: total 1390, average 463.3333333333333, max 1200, min 40
  Alice: 2 posts
  bob: 1 posts
  Jane: 1 posts
```

## Step 6: Update records

Add to `src/crud.cr`:

```crystal
bob.first_name = "Bob"
bob.save                                               # assign, then save
intro.update!(views_count: 151_i64)                    # assign and write in one call
Post.update!(intro.id!, published: true)               # by primary key, without loading
intro.increment_views!                                 # the model method from Part 3

drafts = AppSchema.update.table(:posts).set(published: true).where(user_id: bob.id!, published: false).commit
puts "Bob is #{User.find!(bob.id!).full_name}; intro has #{Post.find!(intro.id!).views_count} views; published #{drafts.rows_affected} draft(s)"
```

```text
...
Bob is Bob; intro has 152 views; published 1 draft(s)
```

`AppSchema.update` writes many rows in one `UPDATE` statement, without loading them.

## Step 7: Search

Add to `src/crud.cr`:

```crystal
def search_posts(term : String)
  Post.where(published: true)
    .where { title.like("%#{term}%") | content.like("%#{term}%") }
    .order(views_count: :desc)
    .all
end
puts "Search 'crystal': #{search_posts("Crystal").map(&.title)}"
```

```text
...
Search 'crystal': ["Crystal Macros", "Getting Started with Crystal"]
```

The pattern is bound as a parameter, so user input is safe to pass.

## Step 8: Process records in batches

Add to `src/crud.cr`:

```crystal
Post.find_each(batch_size: 2) { |post| puts "  batch: #{post.title}" }
```

```text
...
  batch: Getting Started with Crystal
  batch: Crystal Macros
  batch: A Weekend in Lisbon
  batch: Draft Ideas
```

`find_each` reads `batch_size` rows per query instead of the whole table at once.

## Step 9: Delete records

Add to `src/crud.cr`:

```crystal
puts "delete!: #{intro.comments.all.first.delete!}"          # one record, runs destroy callbacks
puts "delete_by!: #{Comment.delete_by!(post_id: intro.id!).rows_affected}"  # one DELETE statement
puts "Post.delete!: #{Post.delete!(intro.id!).rows_affected}"
AppSchema.delete.from(:comments).where { comments.created_at < 1.year.ago }.commit

jane.delete!                                                 # cascades to her posts and their comments
puts "After deleting Jane: #{Post.count} posts"
```

```text
...
delete!: true
delete_by!: 1
Post.delete!: 1
After deleting Jane: 2 posts
```

`delete!` returns `true` when it removed a row. Deleting Jane removes her posts because of the `ON DELETE CASCADE` foreign key from Part 2: the database does it, not a `has_many ... dependent:` option. PostgreSQL and MySQL always enforce foreign keys; SQLite does only with `?foreign_keys=1` on the URL, as Part 1 set.

Next: [Part 5: Adding Features](05-adding-features.md) adds validations, callbacks, transactions and seed data.
