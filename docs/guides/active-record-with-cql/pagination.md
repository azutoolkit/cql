# Pagination

CQL's Active Record provides basic pagination functionality directly on your models, allowing you to easily retrieve records in chunks or pages. This is essential for handling large datasets efficiently, especially in web applications.

The pagination methods are available as class methods on any model that includes `CQL::ActiveRecord::Model(Pk)`.

---

## `page(page_number, per_page \\= 10)`

The `page` method is the primary way to retrieve a specific page of records.

- **`page_number : Int32`**: The desired page number (1-indexed).
- **`per_page : Int32`**: The number of records to include on each page. Defaults to `10`.

It calculates the necessary `offset` and applies a `limit` to the query.

**Example:**

```crystal
# Assuming you have a User model defined:
struct User < CQL::ActiveRecord::Model(Int64)
  db_context YourDB, :users
  # ... properties ...
end

# Get the first page, 10 users per page (default per_page)
page1_users = User.page(1)

# Get the second page, 10 users per page
page2_users = User.page(2)

# Get the third page, with 5 users per page
page3_users_custom_per_page = User.page(3, per_page: 5)

puts "Page 1 Users (#{page1_users.size} users):"
page1_users.each do |user|
  puts "- ID: #{user.id}, Name: #{user.name}"
end

puts "\\nPage 3 Users, 5 per page (#{page3_users_custom_per_page.size} users):"
page3_users_custom_per_page.each do |user|
  puts "- ID: #{user.id}, Name: #{user.name}"
end
```

**How it works internally:**
The method essentially performs:
`query.limit(per_page).offset((page_number - 1) * per_page).all(ModelName)`

---

## `per_page(num_records)`

The `per_page` method, when used as a standalone class method, sets a limit on the number of records returned. It effectively retrieves the _first page_ of records with the specified `num_records` count.

- **`num_records : Int32`**: The number of records to retrieve.

**Example:**

```crystal
# Get the first 5 users
first_5_users = User.per_page(5)

puts "\\nFirst 5 Users (#{first_5_users.size} users):"
first_5_users.each do |user|
  puts "- ID: #{user.id}, Name: #{user.name}"
end
```

**How it works internally:**
The method performs:
`query.limit(num_records).all(ModelName)`

**Note on `per_page`:**
While `per_page` can be called directly on the model class, its name might suggest it's primarily a modifier for other pagination logic (which isn't directly supported by chaining these specific class methods). In most common pagination scenarios, the `page(page_number, per_page)` method is more comprehensive as it handles both the page number and the items per page.

Using `per_page(n)` is equivalent to `page(1, per_page: n)`.

---

## Combining with Other Queries

Pagination methods are applied to the model's default query scope. If you need to paginate a filtered set of records, you would typically chain pagination methods onto a `CQL::Query` object obtained via `YourModel.query`:

```crystal
# Get page 2 of active users, 5 per page
active_users_page2 = User.query
  .where(active: true)
  .order(created_at: :desc)
  .limit(5)  # This is per_page
  .offset((2 - 1) * 5) # This is (page_number - 1) * per_page
  .all(User)

puts "\\nActive Users, Page 2, 5 per page (#{active_users_page2.size} users):"
active_users_page2.each do |user|
  puts "- ID: #{user.id}, Name: #{user.name}, Active: #{user.active}"
end
```

The standalone `User.page` and `User.per_page` methods are convenient for simple, direct pagination on an entire table. For more complex scenarios, building the query and then applying `limit` and `offset` manually (as shown above) provides greater flexibility, and is what `User.page` does internally.

It's important to note that the `Pagination` module in `active_record/pagination.cr` provides these as class methods directly on the model. If you need to paginate a more complex query chain, you'd apply `.limit()` and `.offset()` to the query object itself.
