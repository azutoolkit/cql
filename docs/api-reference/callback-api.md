---
description: >-
  Complete API reference for CQL model callbacks - types, registration, execution order, conditional callbacks, chaining, and best practices.
---

# Callback API Reference

This reference documents all callback features available in CQL's Active Record implementation.

## Overview

Callbacks allow you to hook into the lifecycle of your models and execute custom logic at specific points (e.g., before saving, after creating, before validation, etc.).

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)

  before_save :normalize_email
  after_create :send_welcome_email
  before_validation :set_defaults

  private def normalize_email
    @email = @email.downcase if @email
  end

  private def send_welcome_email
    # ...
  end

  private def set_defaults
    @active = true if @active.nil?
  end
end
```

## Callback Types

### Validation Callbacks

- `before_validation`
- `after_validation`

### Persistence Callbacks

- `before_save`
- `after_save`
- `before_create`
- `after_create`
- `before_update`
- `after_update`
- `before_destroy`
- `after_destroy`

## Callback Registration

### Macro-based Registration

````crystal
before_save :method_name
after_create :method_name

# Registers a method as a callback for the specified event.
# The method must be defined as a private method on the model.

# Example
# ```crystal
# before_save :normalize_email
# private def normalize_email
#   @email = @email.downcase
# end
# ```
````

### Block-based Registration

````crystal
before_save do
  # custom logic
end

# Registers an inline block as a callback for the specified event.
# The block is executed in the context of the model instance.

# Example
# ```crystal
# before_save do
#   self.token = SecureRandom.hex(16)
# end
# ```
````

### Multiple Callbacks

You can register multiple callbacks for the same event:

```crystal
before_save :normalize_email, :set_defaults
```

## Callback Execution Order

Callbacks are executed in the order they are registered. For each event:

- All `before_*` callbacks run before the event
- The main event (e.g., save, create, update) occurs
- All `after_*` callbacks run after the event

## Conditional Callbacks

Callbacks can be made conditional using `if:` and `unless:` options:

```crystal
before_save :normalize_email, if: :email_changed?

private def email_changed?
  # return true if email was changed
end
```

## Callback Chaining

Multiple callbacks can be chained for the same event. Each callback is executed in order. If a `before_*` callback returns `false`, subsequent callbacks and the main event are halted.

```crystal
before_save :check_permissions
before_save :normalize_email

private def check_permissions
  raise "Not allowed" unless admin?
end
```

## Skipping Callbacks

You can skip callbacks by using the `skip_callback` macro:

```crystal
skip_callback :before_save, :normalize_email
```

## Callback Methods

### run_callbacks

````crystal
def run_callbacks(type : Symbol) : Bool

# Description
# Runs all callbacks of the specified type (e.g., :save, :create, :update, :destroy, :validation).

# Parameters
# - **type** [Symbol] Callback type

# Returns
# [Bool] True if all callbacks completed successfully

# Example
# ```crystal
# user.run_callbacks(:save)
# ```
````

### run_save_callbacks

````crystal
def run_save_callbacks(create : Bool = true) : Bool

# Description
# Runs all save-related callbacks, optionally distinguishing between create and update.

# Parameters
# - **create** [Bool] True for create, false for update

# Returns
# [Bool] True if all callbacks completed successfully

# Example
# ```crystal
# user.run_save_callbacks(true)  # for create
# user.run_save_callbacks(false) # for update
# ```
````

### run_after_save_callbacks

````crystal
def run_after_save_callbacks(create : Bool = true) : Bool

# Description
# Runs all after-save callbacks, optionally distinguishing between create and update.

# Parameters
# - **create** [Bool] True for create, false for update

# Returns
# [Bool] True if all callbacks completed successfully

# Example
# ```crystal
# user.run_after_save_callbacks(true)
# ```
````

### run_destroy_callbacks

````crystal
def run_destroy_callbacks : Bool

# Description
# Runs all destroy-related callbacks.

# Returns
# [Bool] True if all callbacks completed successfully

# Example
# ```crystal
# user.run_destroy_callbacks
# ```
````

### run_after_destroy_callbacks

````crystal
def run_after_destroy_callbacks : Bool

# Description
# Runs all after-destroy callbacks.

# Returns
# [Bool] True if all callbacks completed successfully

# Example
# ```crystal
# user.run_after_destroy_callbacks
# ```
````

## Best Practices

- Use callbacks for cross-cutting concerns (normalization, auditing, notifications)
- Avoid business logic in callbacks; keep them focused on model lifecycle
- Use conditional callbacks for performance
- Keep callback methods private
- Document callback side effects

## Example: Full Lifecycle

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)

  before_validation :set_defaults
  before_save :normalize_email
  after_create :send_welcome_email
  before_destroy :archive_user

  private def set_defaults
    @active = true if @active.nil?
  end

  private def normalize_email
    @email = @email.downcase if @email
  end

  private def send_welcome_email
    # ...
  end

  private def archive_user
    # ...
  end
end
```

This API reference provides comprehensive documentation for all callback functionality in CQL. Use it alongside the guides for practical examples and best practices.
