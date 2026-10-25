# Set Up Has One

This guide shows you how to set up a has_one relationship where one model has exactly one related model.

## When to Use

Use `has_one` when:
- A User has one Profile
- An Order has one ShippingAddress
- A Company has one Address

The other model holds the foreign key.

## Schema Setup

```crystal
schema.table :users do
  primary :id, Int64, auto_increment: true
  column :name, String
  timestamps
end
schema.users.create!

schema.table :profiles do
  primary :id, Int64, auto_increment: true
  column :user_id, Int64, null: false
  column :bio, String
  column :avatar_url, String

  timestamps

  foreign_key [:user_id], references: :users, references_columns: [:id]
end
schema.profiles.create!

schema.alter :profiles do
  create_index :idx_profiles_user_id, [:user_id], unique: true
end
```

Note: The unique index ensures only one profile per user. Indexes are created with `schema.alter`, see [Create Indexes](../migrations/indexes.md).

## Options

```crystal
has_one :profile, Profile                       # foreign key defaults to user_id (owner name + _id, without its namespace: Blog::User -> user_id)
has_one :profile, Profile, :user_id             # third argument is the foreign key
has_one :profile, Profile, :user_id, dependent: :nullify, cache: false
```

`dependent` accepts `:destroy`, `:delete` and `:nullify`; any other value is a compile-time error. It decides what happens to an existing profile when you call `create_profile` or `delete_profile` (`:destroy` when not declared). When you declare it, deleting the user applies it too (see [When the Parent Is Deleted](#when-the-parent-is-deleted)). With `cache: true` (the default) the record is cached on the instance after the first access.

`User.preload(:profile).all` loads every user's profile with one extra query (per chunk of the database's bind limit) and caches it, so `user.profile` runs no query. It needs `cache: true`, and it raises `ArgumentError` when the target has no foreign key attribute. As with `user.profile`, a user with several profiles gets an arbitrary one; keep the foreign key unique.

## Define the Relationship

Add `has_one` to the parent model:

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :users

  property id : Int64?
  property name : String

  has_one :profile, Profile, :user_id

  def initialize(@name : String)
  end
end

struct Profile
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :profiles

  property id : Int64?
  property user_id : Int64?
  property bio : String?
  property avatar_url : String?

  belongs_to :user, User, :user_id

  def initialize(@user_id : Int64? = nil, @bio : String? = nil, @avatar_url : String? = nil)
  end
end
```

Declare the foreign key property nilable (`Int64?`) even when the column is `NOT NULL`: `profile=`, `create_profile`, `delete_profile` and `clear_profile` assign `nil` to it (whatever `dependent` is), and they do not compile against an `Int64` property.

## Access the Related Record

```crystal
user = User.find!(1)
profile = user.profile  # Returns Profile?

if profile
  puts "Bio: #{profile.bio}"
else
  puts "No profile"
end
```

## Create Related Record

### Create Profile for User

```crystal
user = User.create!(name: "John")

profile = Profile.create!(
  user_id: user.id!,
  bio: "Hello world",
  avatar_url: "/avatars/john.jpg"
)

user.profile.try(&.bio)  # => "Hello world"
```

### Create Through the Association

```crystal
user = User.create!(name: "John")

profile = user.create_profile(bio: "Hello world")   # sets user_id, saves, caches
other = user.build_profile(bio: "Draft")            # sets user_id, does not save
```

`create_profile` first disposes of an existing profile according to `dependent` (deleted by default).

### Build and Save

```crystal
user = User.find!(1)

profile = Profile.new(user.id!, "My bio")
profile.save!
```

## Update Related Record

```crystal
user = User.find!(1)

if profile = user.profile
  profile.bio = "Updated bio"
  profile.save!
end

# or
user.update_profile(bio: "Updated bio")   # raises AssociationNotFound when there is no profile
```

## Delete Related Record

```crystal
user = User.find!(1)
user.profile.try(&.delete!)

# or follow the `dependent` option (destroy, delete or nullify)
user.delete_profile   # => Bool
user.clear_profile    # nullifies the foreign key, returns Bool
```

## When the Parent Is Deleted

With `dependent:` declared, `user.delete!` handles the profile before deleting the user: `:destroy` calls the profile's `delete!` (callbacks run; if one halts it, `RelationError` is raised and nothing is deleted), `:delete` deletes its row without callbacks, and `:nullify` sets its foreign key to NULL and saves it. The profile is read from the database, not from the cache. Without `dependent:`, deleting the user leaves the profile alone (the database's foreign key decides).

This works as it does for has_many: the strategy and the user's DELETE run in one transaction (a savepoint inside an open one), soft deletes apply it as well, and `User.where(...).delete_all` deletes record by record. See [has_many: When the Parent Is Deleted](has-many.md#when-the-parent-is-deleted).

## Verify It Works

```crystal
user = User.create!(name: "Test User")

profile = Profile.create!(
  user_id: user.id!,
  bio: "Test bio"
)

user.profile.try(&.bio)  # => "Test bio"
profile.user.try(&.name)  # => "Test User"
```

## Related

- [Set Up Belongs To](belongs-to.md)
- [Set Up Has Many](has-many.md)
- [Define a Model](../models/define-model.md)
