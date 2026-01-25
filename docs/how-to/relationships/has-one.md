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

  foreign_key [:user_id], references: :users, references_columns: [:id]
  index [:user_id], unique: true
  timestamps
end
schema.profiles.create!
```

Note: The unique index ensures only one profile per user.

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
  property user_id : Int64
  property bio : String?
  property avatar_url : String?

  belongs_to :user, User, :user_id

  def initialize(@user_id : Int64, @bio : String? = nil, @avatar_url : String? = nil)
  end
end
```

## Access the Related Record

```crystal
user = User.find(1)
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
  user_id: user.id.not_nil!,
  bio: "Hello world",
  avatar_url: "/avatars/john.jpg"
)

user.profile.try(&.bio)  # => "Hello world"
```

### Build and Save

```crystal
user = User.find(1)

profile = Profile.new(user.id.not_nil!, "My bio")
profile.save!
```

## Update Related Record

```crystal
user = User.find(1)

if profile = user.profile
  profile.bio = "Updated bio"
  profile.save!
end
```

## Delete Related Record

```crystal
user = User.find(1)
user.profile.try(&.delete!)
```

## Verify It Works

```crystal
user = User.create!(name: "Test User")

profile = Profile.create!(
  user_id: user.id.not_nil!,
  bio: "Test bio"
)

user.profile.try(&.bio)  # => "Test bio"
profile.user.try(&.name)  # => "Test User"
```

## Related

- [Set Up Belongs To](belongs-to.md)
- [Set Up Has Many](has-many.md)
- [Define a Model](../models/define-model.md)
