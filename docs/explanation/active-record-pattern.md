# Active Record Pattern

In the Active Record pattern a class wraps a table and each instance wraps one row, carrying both the data and the code that saves it. It is the pattern CQL's models follow.

## The Model Holds Data, Rules and Persistence

```crystal
class User
  include CQL::ActiveRecord::Model(Int64) # adds id : Int64?
  db_context AppDB, :users

  property name : String
  property email : String
  property active : Bool = true

  validate :name, presence: true
  validate :email, presence: true, match: /@/

  before_save :normalize_email

  def initialize(@name : String, @email : String)
  end

  # Business logic and persistence side by side
  def deactivate!
    @active = false
    save
  end

  private def normalize_email
    @email = @email.downcase.strip
    true
  end
end
```

One class answers every question about a user: which columns it has, which values are valid, what happens before it is written, and what the business operations are.

## An Instance Saves, Updates and Deletes Itself

```crystal
user = User.new("Ada", "ADA@example.com")
user.save        # INSERT INTO users (name, email, active) VALUES (?, ?, ?); assigns user.id
user.email       # => "ada@example.com" (normalized by before_save)
user.name = "Ada L."
user.save        # UPDATE users SET name = ?, email = ?, active = ? WHERE users.id = ?
user.deactivate! # => true
user.delete!     # DELETE FROM users WHERE users.id = ?; user.id is nil again
```

Models are classes, not structs: `save` assigns the generated `id` to the very instance you hold, which a struct copy would not see.

## The Class Is the Query Entry Point

```crystal
User.find(1)                           # User?, nil when missing
User.find!(1)                          # User, raises DB::NoResultsError when missing
User.find_by(email: "ada@example.com") # User?
User.where(active: true).all           # Array(User)
User.count                             # Int64 | Int32
```

## Validations and Callbacks Guard Each Write

```crystal
draft = User.new("", "invalid")
draft.valid?                # => false
draft.errors.map(&.message) # => ["name must be present", "email must match the pattern /@/"]
draft.save                  # raises CQL::ActiveRecord::Validations::ValidationError; nothing is written
```

| Call | Invalid record | A `before_*` callback returns `false` |
| :--- | :--- | :--- |
| `user.save` | raises `CQL::ActiveRecord::Validations::ValidationError` | returns `false` |
| `user.save!` | raises `ValidationError` | raises `CQL::RecordNotSaved` |
| `user.create!` | raises `ValidationError` | callbacks do not run |
| `User.create!(name: "", email: "x")` | inserts without validating | callbacks do not run |

`save` validates once, before `before_save`, so a value a callback sets is not validated. A callback halts the save only by returning `false`; any other value, including `nil`, lets it continue. Beyond `presence` and `match`, `validate` accepts `eq`, `exclude`, `gt`, `gte`, `in`, `lt`, `lte`, `size`, `required`, `confirmation` and `accept`, and the hooks run before and after validation, save, create, update and destroy. See [Add Validations](../how-to/models/add-validations.md), [Use Callbacks](../how-to/models/use-callbacks.md) and [Callback Hooks](../reference/api/callback-hooks.md).

## Associations Are Declared on the Model

```crystal
class Post
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :posts

  property user_id : Int64
  property title : String
  property slug : String = ""

  belongs_to :user, User, :user_id
  has_many :comments, Comment, :post_id

  validate :title, presence: true
  before_save :update_slug

  def initialize(@title : String, @user_id : Int64)
  end

  private def update_slug
    @slug = @title.downcase.gsub(/[^a-z0-9]+/, "-").strip('-')
    true
  end
end

author = User.create!(name: "Grace", email: "grace@example.com")
post = Post.new("Hello, World!", author.id!)
post.save
post.slug                 # => "hello-world"
post.user                 # User?, one SELECT on first access
post.comments.all         # Array(Comment); the post must be saved first
```

## Trade-offs

| Strength | Cost |
| :--- | :--- |
| Code reads like the domain: `user.save`, `post.comments` | Domain logic is coupled to the table layout; a schema change can ripple into business code |
| Everything about an entity is in one class | Models in a large domain grow into long classes |
| Little setup: no mapper or repository layer | Testing a model usually needs a database (an in-memory SQLite file works well) |

Active Record fits CRUD-heavy applications, prototypes, and domains whose objects look like their tables. When business rules must not know about storage, data comes from more than one source, or tests must run without a database, consider the [Repository pattern](repository-pattern.md).

| Pattern | Holds the data | Talks to the database | In CQL |
| :--- | :--- | :--- | :--- |
| Active Record | the model | the model | `include CQL::ActiveRecord::Model(Int64)` |
| Repository | a plain entity | the repository | `CQL::Repository(T, Pk)`, or your own class around a model |
| Data Mapper | a plain entity | a mapper that knows both | not provided |
