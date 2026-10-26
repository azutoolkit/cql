# Test Models

Spec validations, persistence, callbacks, associations and scopes of CQL models against a test database.

## The Models Under Test

```crystal
class User
  include CQL::ActiveRecord::Model(Int64)
  # name, email, created_at, updated_at properties, has_many :posts

  validate :name, presence: true
  validate :email, match: /\A[^@\s]+@[^@\s]+\z/, message: "is not an email"
end

class Post
  include CQL::ActiveRecord::Model(Int64)
  # title, body, slug, published, user_id properties, belongs_to :user, has_many :comments

  before_save :generate_slug
  scope :published, -> { where(published: true) }
  scope :draft, -> { where(published: false) }

  private def generate_slug
    @slug = title.downcase.gsub(/[^a-z0-9]+/, "-").strip('-')
    true
  end
end
```

[Set Up Test Databases](test-database.md) creates the tables and rolls back each example.

## Validations

```crystal
describe User do
  it "is valid with a name and an email" do
    User.new("John", "john@example.com").valid?.should be_true
  end

  it "reports the failing field" do
    user = User.new("John", "invalid-email")
    user.valid?.should be_false
    user.errors.map(&.field).should contain(:email)
  end
end
```

## Persistence

```crystal
describe User do
  it "inserts the row and sets id and timestamps" do
    user = User.new("John", "john@example.com")
    user.save.should be_true
    user.id.should_not be_nil
    user.created_at.should_not be_nil
  end

  it "raises for an invalid record" do
    expect_raises(CQL::ActiveRecord::Validations::ValidationError) do
      User.new("John", "invalid-email").save   # save raises; it does not return false
    end
  end

  it "finds by id" do
    User.find(0).should be_nil
    expect_raises(DB::NoResultsError) { User.find!(0) }
  end
end
```

## Callbacks

```crystal
describe Post do
  it "generates a slug before save" do
    post = Post.new("Hello World", "Content")
    post.save
    post.slug.should eq("hello-world")
  end

  # ❌ Post.create!(title: "Hello World", body: "x").slug  # => "": create! runs no callbacks
end
```

## Associations and Scopes

```crystal
describe Post do
  it "belongs to a user and has many comments" do
    user = Factory.user
    post = Factory.post(user)
    Comment.create!(post_id: post.id!, body: "Nice!")
    Comment.create!(post_id: post.id!, body: "Great!")

    post.user.try(&.id).should eq(user.id)
    post.comments.count.should eq(2)
  end

  it "filters with scopes" do
    Post.create!(title: "Published", body: "...", published: true)
    Post.create!(title: "Draft", body: "...")

    Post.published.count.should eq(1)
    Post.published.first!.title.should eq("Published")
    Post.draft.count.should eq(1)
  end
end
```

## Factories

```crystal
# spec/support/factory.cr
module Factory
  def self.user(name = "Test User", email = "user#{Random.rand(1_000_000)}@example.com") : User
    User.create!(name: name, email: email)
  end

  def self.post(user : User = self.user, title = "Test Post") : Post
    Post.create!(user_id: user.id!, title: title, body: "Content")
  end
end
```

`create!` skips validations and callbacks, which keeps factories fast; build with `new` and `save` when a spec needs
them to run.

## Run the Specs

```bash
crystal spec                               # every spec
crystal spec spec/models/user_spec.cr      # one file
crystal spec spec/models/user_spec.cr:12   # the example on line 12
crystal spec --verbose                     # one line per example
```

## See Also

- [Set Up Test Databases](test-database.md)
- [Create Records](../data-operations/create.md)
- [Add Validations](../models/add-validations.md)
- [Use Callbacks](../models/use-callbacks.md)
- [Create Query Scopes](../querying/scopes.md)
