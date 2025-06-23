# Touch - Update Timestamps Without Callbacks

The Touch functionality in CQL Active Record allows you to update timestamp fields (like `updated_at`, `created_at`, or custom timestamp fields) without triggering any callbacks like validations, before/after save hooks, or other lifecycle callbacks.

This is particularly useful when you want to mark records as "recently accessed" or update timestamps for logging purposes without running the full save cycle.

## Overview

Touch provides a lightweight way to update timestamp columns directly in the database, bypassing the entire Active Record callback chain including:

- Validation callbacks (`before_validation`, `after_validation`)
- Save callbacks (`before_save`, `after_save`)
- Create/Update callbacks (`before_create`, `after_create`, `before_update`, `after_update`)

## Basic Usage

### Instance Methods

#### `#touch(*fields, time: Time = Time.utc)`

Updates specified timestamp fields to the current time (or a custom time) without running callbacks.

```crystal
# Touch the default updated_at field
user.touch
# => Updates user.updated_at to current time

# Touch specific timestamp fields
user.touch(:last_seen_at)
# => Updates user.last_seen_at to current time

# Touch multiple fields
user.touch(:updated_at, :last_accessed_at)
# => Updates both fields to current time

# Touch with custom time
specific_time = Time.utc - 1.hour
user.touch(:updated_at, time: specific_time)
# => Updates user.updated_at to the specified time
```

#### `#touch!(time: Time = Time.utc)`

Convenience method that specifically touches the `updated_at` field.

```crystal
user.touch!
# => Equivalent to user.touch(:updated_at)

user.touch!(time: Time.utc - 2.hours)
# => Updates updated_at to 2 hours ago
```

### Class Methods

#### `.touch_all(ids, *fields, time: Time = Time.utc)`

Updates timestamp fields for multiple records by their IDs without loading them into memory or running callbacks.

```crystal
# Touch updated_at for multiple records
User.touch_all([1, 2, 3, 4, 5])
# => Updates updated_at for users with IDs 1-5

# Touch specific fields for multiple records
User.touch_all([1, 2, 3], :last_seen_at, :updated_at)
# => Updates both timestamp fields for specified users

# Touch with custom time
User.touch_all([1, 2, 3], time: Time.utc - 30.minutes)
# => Updates updated_at to 30 minutes ago for specified users
```

## Examples

### Basic Record Touching

```crystal
struct User
  include CQL::ActiveRecord::Model(Int32)
  db_context UserDB, :users

  property name : String
  property email : String
  property created_at : Time?
  property updated_at : Time?
  property last_seen_at : Time?

  # Callbacks for demonstration
  before_save :log_save
  after_update :send_notification

  private def log_save
    puts "User is being saved!"
    true
  end

  private def send_notification
    puts "User was updated - sending notification"
    true
  end
end

user = User.create!(name: "John", email: "john@example.com")

# Regular save triggers callbacks
user.name = "Johnny"
user.save!
# Output: "User is being saved!"
# Output: "User was updated - sending notification"

# Touch bypasses all callbacks
user.touch
# No output - callbacks are skipped
# But updated_at is still updated in the database
```

### Tracking User Activity

```crystal
# Mark user as recently active without triggering notifications
user.touch(:last_seen_at)

# Update multiple activity timestamps
user.touch(:last_seen_at, :last_login_at, :updated_at)

# Batch update activity for multiple users
recently_active_user_ids = [1, 5, 10, 15, 23]
User.touch_all(recently_active_user_ids, :last_seen_at)
```

### Cache Invalidation

```crystal
# Touch a record to invalidate cached associations or computed values
# without triggering expensive callbacks
post.touch  # Updates post.updated_at to invalidate caches

# Touch multiple related records
Post.touch_all(comment.post_ids, :updated_at)
```

## Behavior Details

### What Touch Does

1. **Updates Database Directly**: Executes an UPDATE query directly against the database
2. **Updates Local Instance**: Synchronizes the local object's timestamp attributes with the database
3. **Returns Success Status**: Returns `true` if the update was successful, `false` otherwise
4. **No Callbacks**: Completely bypasses all Active Record callbacks and validations

### What Touch Doesn't Do

1. **No Validation**: Does not run any model validations
2. **No Callbacks**: Does not trigger any lifecycle callbacks
3. **No Dirty Tracking**: Does not mark attributes as changed/dirty
4. **No Version Bumping**: Does not increment optimistic locking version numbers

### Error Conditions

Touch will raise errors in these situations:

```crystal
# Attempting to touch non-persisted records
new_user = User.new(name: "Test")
new_user.touch  # Raises: "Cannot touch on a new record object"

# Attempting to touch non-existent columns
user.touch(:nonexistent_field)  # Raises: "Unknown column: nonexistent_field"
```

## Use Cases

### 1. Activity Tracking

Update `last_seen_at` timestamps when users access the application:

```crystal
class UserActivityService
  def track_user_activity(user_id)
    # Efficient way to update activity without callbacks
    User.touch_all([user_id], :last_seen_at)
  end
end
```

### 2. Cache Invalidation

Mark records as updated to invalidate cached data:

```crystal
class CacheInvalidationService
  def invalidate_post_cache(post_ids)
    # Touch posts to update their timestamps for cache invalidation
    Post.touch_all(post_ids, :updated_at)
  end
end
```

### 3. Background Job Processing

Update processing timestamps in background jobs:

```crystal
class DocumentProcessingJob
  def perform(document_id)
    document = Document.find!(document_id)

    # Mark as processing started
    document.touch(:processing_started_at)

    # ... do heavy processing ...

    # Mark as processing completed
    document.touch(:processing_completed_at)
  end
end
```

### 4. API Rate Limiting

Track API usage without expensive model updates:

```crystal
class ApiUsageTracker
  def track_api_call(user_id)
    # Lightweight timestamp update for rate limiting
    User.touch_all([user_id], :last_api_call_at)
  end
end
```

## Performance Benefits

Touch is significantly more performant than regular saves because it:

- Skips validation logic
- Bypasses callback chains
- Executes minimal SQL UPDATE statements
- Doesn't instantiate full objects for batch operations
- Avoids complex change tracking

This makes it ideal for high-frequency timestamp updates like activity tracking, cache invalidation, and background processing scenarios.

## Comparison with Regular Save

| Operation             | Callbacks            | Validations        | SQL Queries                      | Performance |
| --------------------- | -------------------- | ------------------ | -------------------------------- | ----------- |
| `user.save!`          | ✅ All callbacks run | ✅ Full validation | Multiple (if callbacks query DB) | Slower      |
| `user.touch`          | ❌ No callbacks      | ❌ No validation   | Single UPDATE                    | Faster      |
| `User.touch_all(ids)` | ❌ No callbacks      | ❌ No validation   | Single UPDATE with IN clause     | Fastest     |

## Best Practices

1. **Use for Timestamp Updates**: Touch is designed specifically for timestamp fields
2. **Prefer Batch Operations**: Use `touch_all` for updating multiple records efficiently
3. **Avoid for Business Logic**: Don't use touch when you need validations or callbacks
4. **Consider Cache Impact**: Remember that touching may affect timestamp-based caching
5. **Monitor Performance**: Touch is fast, but avoid excessive database updates in tight loops

## Integration with Existing Code

Touch integrates seamlessly with existing Active Record models. Simply add timestamp properties to your models and start using the touch methods:

```crystal
# Add timestamp properties to existing models
property last_seen_at : Time?
property last_login_at : Time?
property processing_started_at : Time?

# Use touch methods immediately
user.touch(:last_seen_at)
```

The touch functionality respects your existing schema and will work with any Time-typed columns in your database tables.
