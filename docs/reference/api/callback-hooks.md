---
description: "The ten lifecycle callback macros, the order they run in, and which persistence calls run them."
---

# Callback Hooks Reference

Every callback names an instance method; there are no block, `if:`, `unless:` or `around_*` forms.

## Macros

| Macro | Runs | `false` halts |
| :--- | :--- | :--- |
| **`before_validation :method`** | First in every `save` | `save` returns `false` before validating |
| **`after_validation :method`** | After the rules pass; an invalid record raises `ValidationError` before it runs | `save` returns `false` |
| **`before_save :method`** | After validation passes, for inserts and updates | `save` returns `false` |
| **`before_create :method`** | After `before_save`, new records only | `save` returns `false` |
| **`before_update :method`** | After `before_save`, records with an id only | `save` returns `false` |
| **`after_create :method`** | After the INSERT | later `after_create` callbacks only |
| **`after_update :method`** | After the UPDATE | later `after_update` callbacks only |
| **`after_save :method`** | Last in `save`, after `after_create` / `after_update` | later `after_save` callbacks only |
| **`before_destroy :method`** | First in the instance `delete!` (and soft-delete `delete!` / `force_delete!`) | `delete!` returns `false`; nothing is deleted |
| **`after_destroy :method`** | After a DELETE that removed a row, before `id` is cleared | later `after_destroy` callbacks only |

Several callbacks for one event run in the order they are declared.

<details>
<summary>A model that declares all ten</summary>

```crystal
class Post
  include CQL::ActiveRecord::Model(Int64)

  property title : String = ""
  property slug : String = ""
  property published : Bool = false
  property published_at : Time?

  before_validation :strip_title      # @title = @title.strip
  after_validation :log_attempt       # runs once the rules pass
  before_save :set_slug               # inserts and updates
  before_create :default_title        # inserts only
  before_update :stamp_publish        # updates only
  after_create :log_created
  after_update :log_updated
  after_save :log_saved
  before_destroy :keep_published      # false keeps the row
  after_destroy :log_destroyed

  def initialize(@title : String = "")
  end

  private def strip_title
    @title = @title.strip
    true
  end

  private def log_attempt
    puts "validating post #{@title}"
    true
  end

  private def set_slug
    @slug = @title.downcase.gsub(/[^a-z0-9]+/, "-")
    true
  end

  private def default_title
    @title = "Untitled" if @title.empty?
    true
  end

  private def stamp_publish
    @published_at ||= Time.utc if @published
    true
  end

  private def log_created
    puts "created post #{@id}"
    true
  end

  private def log_updated
    puts "updated post #{@id}"
    true
  end

  private def log_saved
    puts "saved post #{@id}"
    true
  end

  private def keep_published
    !@published
  end

  private def log_destroyed
    puts "deleted post #{@id}"
    true
  end
end
```

</details>

## Order

| Step | `save` on a new record | `save` on a record with an id | `delete!` |
| :--- | :--- | :--- | :--- |
| 0 | timestamps set | timestamps set | `dependent: :restrict_with_error` check (raises `RelationError`) |
| 1 | `before_validation` | `before_validation` | `before_destroy` |
| 2 | validation rules (raise `ValidationError` when invalid) | validation rules | `DELETE` (with `dependent:` handling) |
| 3 | `after_validation` | `after_validation` | `after_destroy` |
| 4 | `before_save` | `before_save` | `id` cleared |
| 5 | `before_create` | `before_update` | |
| 6 | `INSERT` | `UPDATE` | |
| 7 | `after_create` | `after_update` | |
| 8 | `after_save` | `after_save` | |

```crystal
post = Post.new("  Hello  ")
post.save    # before_validation, after_validation, before_save, before_create, after_create, after_save
post.save    # before_validation, after_validation, before_save, before_update, after_update, after_save
post.delete! # before_destroy, after_destroy
```

## Which calls run callbacks

| Call | Callbacks | Validates |
| :--- | :--- | :--- |
| `record.save`, `record.save!` | save callbacks | yes (raises `ValidationError`) |
| `record.delete!`; soft-delete `delete!`, `force_delete!` | destroy callbacks | no |
| `Post.where(...).delete_all` when the model declares destroy callbacks, `dependent:` or `many_to_many` | each record's destroy callbacks, in one transaction | no |
| `has_many` / `has_one ..., dependent: :destroy` | the child's destroy callbacks | no |
| `record.create!`, `collection.create(**attrs)` | none | yes |
| `Model.create!(**attrs)`, `Model.create!(record)`, `collection.create(record)` | none | no |
| `record.update!`, `Model.update!(id, attrs)`, `Model.update_by`, `Model.update_all` | none | no |
| `Model.delete!(id)`, `Model.delete_by!`, `Model.delete_all`, `Post.where(...).delete_all` otherwise | none | no |
| `record.touch`, `restore!`, `insert_all`, `upsert_all` | none | no |

## Return values

| Callback returns | Effect |
| :--- | :--- |
| `false` from a `before_*` or `after_validation` | `save` returns `false` and `save!` raises `CQL::RecordNotSaved`; `delete!` returns `false`. Nothing is added to `errors`. |
| `false` from an `after_*` | The remaining callbacks of that event are skipped; the next event still runs (`after_save` follows a halted `after_create`). The database change stays. |
| anything else, including `nil` | The chain continues. Return `true` explicitly so a trailing `false` cannot halt by accident. |

## Helper methods

| Method | Returns | Behavior |
| :--- | :--- | :--- |
| `record.run_callbacks(type : Symbol)` | `Bool` | Runs the callbacks for one event (`:before_save`, ...); `false` when one returned `false`. |
| `record.run_destroy_callbacks`, `record.run_after_destroy_callbacks` | `Bool` | `before_destroy` / `after_destroy`. |
| `Model.destroy_callbacks?` | `Bool` | `true` when the model declares `before_destroy` or `after_destroy`. |

```crystal
post.run_callbacks(:before_save) # => true
Post.destroy_callbacks?          # => true
```

## See Also

- [Use Callbacks](../../how-to/models/use-callbacks.md)
- [Track Changes (DirtyTracking)](../../how-to/models/dirty-tracking.md)
- [Validation Options](validation-options.md)
- [Error Codes](../error-codes.md)
