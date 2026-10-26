# Set Up Has One

Declare `has_one` on the model whose single related record holds the foreign key, such as a `User` with one `Profile`.

## Declare the Association

```crystal
AppDB = CQL::Schema.define(:app_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3://./app.db") do
  table :users do
    primary :id, Int64, auto_increment: true
    column :name, String
  end

  table :profiles do
    primary :id, Int64, auto_increment: true
    column :user_id, Int64, null: true
    column :bio, String, default: ""
    foreign_key [:user_id], references: :users, references_columns: [:id]
    index [:user_id], unique: true   # one profile per user
  end
end

class User
  include CQL::ActiveRecord::Model(Int64)

  property name : String = ""

  has_one :profile, Profile, dependent: :destroy
end

class Profile
  include CQL::ActiveRecord::Model(Int64)

  property user_id : Int64?          # nilable even when the column is NOT NULL
  property bio : String = ""

  belongs_to :user, User, :user_id

  def initialize(@bio : String = "")
  end
end
```

```crystal
has_one :profile, Profile                  # foreign key user_id: owner name + _id (Blog::User -> user_id)
has_one :profile, Profile, :owner_id       # or foreign_key: :owner_id
has_one :profile, Profile, dependent: :nullify, cache: false
```

| Option | Default | Effect |
|---|---|---|
| `dependent:` | not declared | `:destroy`, `:delete` or `:nullify` (anything else fails to compile). Disposes of the old profile in `create_profile` and `delete_profile` (`:destroy` when not declared), and applies when the user is deleted. |
| `cache:` | `true` | The profile is cached on the user after the first read. With `false`, `preload(:profile)` silently skips it. |

The foreign key must be its own column: a foreign key that is also the target's primary key fails to compile, so declare `belongs_to` from the target instead. Declare it nilable, because `profile=`, `create_profile`, `delete_profile` and `clear_profile` assign `nil` to it.

## Read the Profile

```crystal
user = User.find!(1)
user.profile.try(&.bio)     # => "Hello" (Profile?, then cached; reload_profile reads again)

User.preload(:profile).all  # one extra query per chunk of the bind limit
```

`preload` raises `ArgumentError` when `Profile` has no foreign key attribute. A user with several profiles gets an arbitrary one, so keep the foreign key unique.

## Create, Update and Remove the Profile

```crystal
user = User.create!(name: "Ada")

Profile.create!(user_id: user.id!, bio: "Hello")    # set the foreign key directly
user.create_profile(bio: "Hello again")  # disposes of the old one per dependent:, validates, INSERTs, caches
user.build_profile(bio: "Draft")         # Profile.new(bio: "Draft") with user_id set; not saved
user.profile = Profile.new("Assigned")   # unlinks the old one (user_id = nil), then save!s this one

user.update_profile(bio: "Edited")       # update!, no validation; AssociationNotFound when there is none
user.delete_profile                      # => Bool, per dependent:
user.clear_profile                       # => Bool, sets user_id to nil and saves the profile
```

## When the Parent Is Deleted

With `dependent:` declared, `user.delete!` reads the profile from the database (not the cache) and disposes of it first:

| `dependent:` | Effect on the profile |
|---|---|
| `:destroy` | Calls its `delete!`, so its callbacks run. If one halts, `RelationError` is raised and nothing is deleted. |
| `:delete` | Deletes its row without callbacks |
| `:nullify` | Sets `user_id` to NULL and saves it |
| not declared | Nothing; the database's foreign key decides |

The strategy and the user's `DELETE` run in one transaction, soft deletes apply it too, and `User.where(...).delete_all` goes record by record, as for [has_many](has-many.md#when-the-parent-is-deleted).

## See Also

- [Set Up Belongs To](belongs-to.md)
- [Set Up Has Many](has-many.md)
- [Avoid N+1 Queries](../performance/n-plus-one.md)
- [Create Indexes](../migrations/indexes.md)
- [Define a Model](../models/define-model.md)
