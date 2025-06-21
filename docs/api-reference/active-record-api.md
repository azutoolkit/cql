---
description: >-
  Complete API reference for CQL's Active Record implementation - model definition, CRUD operations, querying, and lifecycle methods.
---

# Active Record API Reference

This reference documents all methods and features available in CQL's Active Record implementation.

## Model Definition

### CQL::ActiveRecord::Model(Pk)

The main module that provides Active Record functionality to your models.

````crystal
module CQL::ActiveRecord::Model(Pk)
  # Description
  # Provides Active Record functionality including CRUD operations, validations,
  # callbacks, relationships, and querying capabilities.

  # Features
  # - Type-safe model definition with primary key specification
  # - Automatic database serialization
  # - Built-in validation system
  # - Lifecycle callbacks
  # - Relationship management
  # - Query interface integration

  # Example
  # ```crystal
  # struct User
  #   include CQL::ActiveRecord::Model(Int64)
  #   db_context AcmeDB, :users
  #
  #   getter id : Int64?
  #   getter name : String
  #   getter email : String
  # end
  # ```
end
````

### db_context

Defines the database context and table name for the model.

````crystal
db_context DatabaseContext, :table_name

# Description
# Associates the model with a specific database context and table.

# Parameters
# - **DatabaseContext** [Module] The database context module/class
# - **table_name** [Symbol] The database table name

# Example
# ```crystal
# struct User
#   include CQL::ActiveRecord::Model(Int64)
#   db_context AcmeDB, :users
# end
# ```
````

## Query Interface Methods

### Class Methods

#### query

````crystal
def self.query : QueryBuilder(T)

# Description
# Creates a new query builder instance for this model.

# Returns
# [QueryBuilder(T)] A query builder configured for this model

# Example
# ```crystal
# User.query.where(active: true).all
# ```
````

#### select

````crystal
def self.select(*columns : Symbol | String) : QueryBuilder(T)
def self.select(**fields) : QueryBuilder(T)

# Description
# Creates a query builder and selects specific columns.

# Parameters
# - **columns** [Symbol | String*] Column names to select
# - **fields** [Hash] Hash-based column selection

# Returns
# [QueryBuilder(T)] Query builder with column selection

# Example
# ```crystal
# User.select(:name, :email).all
# User.select(users: [:name], profiles: [:bio]).all
# ```
````

#### where

````crystal
def self.where(conditions : Hash(String | Symbol, DB::Any | Array(DB::Any))) : QueryBuilder(T)
def self.where(**fields) : QueryBuilder(T)
def self.where(&block) : QueryBuilder(T)

# Description
# Creates a query builder with filtering conditions.

# Parameters
# - **conditions** [Hash] Conditions hash
# - **fields** [Hash] Named arguments for conditions
# - **block** [Block] Block for complex conditions

# Returns
# [QueryBuilder(T)] Query builder with conditions

# Example
# ```crystal
# User.where(active: true).all
# User.where(age: 18..65).all
# User.where { |f| f.gt(:age, 18) }.all
# ```
````

#### where_like

````crystal
def self.where_like(field : Symbol | String, pattern : String) : QueryBuilder(T)

# Description
# Creates a query builder with LIKE pattern matching.

# Parameters
# - **field** [Symbol | String] Field name to match
# - **pattern** [String] SQL LIKE pattern

# Returns
# [QueryBuilder(T)] Query builder with LIKE condition

# Example
# ```crystal
# User.where_like(:name, "John%").all
# ```
````

#### order

````crystal
def self.order(*fields : Symbol | String) : QueryBuilder(T)
def self.order(**fields) : QueryBuilder(T)

# Description
# Creates a query builder with ordering.

# Parameters
# - **fields** [Symbol | String*] Fields to order by
# - **fields** [Hash] Hash-based ordering with directions

# Returns
# [QueryBuilder(T)] Query builder with ordering

# Example
# ```crystal
# User.order(:name).all
# User.order(name: :asc, created_at: :desc).all
# ```
````

#### limit

````crystal
def self.limit(value : Int32) : QueryBuilder(T)

# Description
# Creates a query builder with result limiting.

# Parameters
# - **value** [Int32] Maximum number of results

# Returns
# [QueryBuilder(T)] Query builder with limit

# Example
# ```crystal
# User.limit(10).all
# ```
````

#### offset

````crystal
def self.offset(value : Int32) : QueryBuilder(T)

# Description
# Creates a query builder with result offset.

# Parameters
# - **value** [Int32] Number of results to skip

# Returns
# [QueryBuilder(T)] Query builder with offset

# Example
# ```crystal
# User.offset(20).limit(10).all
# ```
````

#### group

````crystal
def self.group(*columns : Symbol | String) : QueryBuilder(T)

# Description
# Creates a query builder with grouping.

# Parameters
# - **columns** [Symbol | String*] Columns to group by

# Returns
# [QueryBuilder(T)] Query builder with grouping

# Example
# ```crystal
# User.group(:role).count
# ```
````

#### group_by

````crystal
def self.group_by(*columns : Symbol | String) : QueryBuilder(T)

# Description
# Alias for group method.

# Parameters
# - **columns** [Symbol | String*] Columns to group by

# Returns
# [QueryBuilder(T)] Query builder with grouping

# Example
# ```crystal
# User.group_by(:role).count
# ```
````

#### having

````crystal
def self.having(&block) : QueryBuilder(T)

# Description
# Creates a query builder with HAVING conditions.

# Parameters
# - **block** [Block] Block for HAVING conditions

# Returns
# [QueryBuilder(T)] Query builder with HAVING clause

# Example
# ```crystal
# User.group(:role).having { |h| h.gt(:count, 5) }.all
# ```
````

#### distinct

````crystal
def self.distinct : QueryBuilder(T)

# Description
# Creates a query builder with distinct results.

# Returns
# [QueryBuilder(T)] Query builder with distinct clause

# Example
# ```crystal
# User.select(:role).distinct.all
# ```
````

#### join

````crystal
def self.join(table_or_alias : Symbol) : QueryBuilder(T)
def self.join(table_or_alias : Symbol, &block : Expression::FilterBuilder -> _) : QueryBuilder(T)
def self.join(**tables_with_aliases) : QueryBuilder(T)

# Description
# Creates a query builder with INNER JOIN.

# Parameters
# - **table_or_alias** [Symbol] Table name or alias
# - **block** [Block] Block for join conditions
# - **tables_with_aliases** [Hash] Table name => alias mapping

# Returns
# [QueryBuilder(T)] Query builder with join

# Example
# ```crystal
# User.join(:posts).all
# User.join(:posts) { |j| j.on(:user_id, :id) }.all
# ```
````

#### left

````crystal
def self.left(table_or_alias : Symbol) : QueryBuilder(T)
def self.left(table_or_alias : Symbol, &block : Expression::FilterBuilder -> _) : QueryBuilder(T)
def self.left(**tables_with_aliases) : QueryBuilder(T)

# Description
# Creates a query builder with LEFT JOIN.

# Parameters
# - **table_or_alias** [Symbol] Table name or alias
# - **block** [Block] Block for join conditions
# - **tables_with_aliases** [Hash] Table name => alias mapping

# Returns
# [QueryBuilder(T)] Query builder with left join

# Example
# ```crystal
# User.left(:profiles).all
# ```
````

#### right

````crystal
def self.right(table_or_alias : Symbol) : QueryBuilder(T)
def self.right(table_or_alias : Symbol, &block : Expression::FilterBuilder -> _) : QueryBuilder(T)
def self.right(**tables_with_aliases) : QueryBuilder(T)

# Description
# Creates a query builder with RIGHT JOIN.

# Parameters
# - **table_or_alias** [Symbol] Table name or alias
# - **block** [Block] Block for join conditions
# - **tables_with_aliases** [Hash] Table name => alias mapping

# Returns
# [QueryBuilder(T)] Query builder with right join

# Example
# ```crystal
# User.right(:profiles).all
# ```
````

### Aggregation Methods

#### count

````crystal
def self.count(column : Symbol = :*) : Int64

# Description
# Counts records matching the query.

# Parameters
# - **column** [Symbol] Column to count (default: :*)

# Returns
# [Int64] Number of records

# Example
# ```crystal
# User.count
# User.where(active: true).count
# ```
````

#### sum

````crystal
def self.sum(column : Symbol) : Float64

# Description
# Sums values in the specified column.

# Parameters
# - **column** [Symbol] Column to sum

# Returns
# [Float64] Sum of values

# Example
# ```crystal
# User.sum(:score)
# ```
````

#### avg

````crystal
def self.avg(column : Symbol) : Float64

# Description
# Calculates average of values in the specified column.

# Parameters
# - **column** [Symbol] Column to average

# Returns
# [Float64] Average value

# Example
# ```crystal
# User.avg(:age)
# ```
````

#### min

````crystal
def self.min(column : Symbol) : DB::Any

# Description
# Finds minimum value in the specified column.

# Parameters
# - **column** [Symbol] Column to find minimum

# Returns
# [DB::Any] Minimum value

# Example
# ```crystal
# User.min(:age)
# ```
````

#### max

````crystal
def self.max(column : Symbol) : DB::Any

# Description
# Finds maximum value in the specified column.

# Parameters
# - **column** [Symbol] Column to find maximum

# Returns
# [DB::Any] Maximum value

# Example
# ```crystal
# User.max(:age)
# ```
````

### Execution Methods

#### all

````crystal
def self.all : Array(T)

# Description
# Executes the query and returns all results.

# Returns
# [Array(T)] Array of model instances

# Example
# ```crystal
# User.all
# User.where(active: true).all
# ```
````

#### first

````crystal
def self.first : T?

# Description
# Executes the query and returns the first result.

# Returns
# [T?] First model instance or nil

# Example
# ```crystal
# User.first
# User.where(active: true).first
# ```
````

#### first!

````crystal
def self.first! : T

# Description
# Executes the query and returns the first result, raising if not found.

# Returns
# [T] First model instance

# Raises
# [CQL::RecordNotFound] When no record is found

# Example
# ```crystal
# User.first!
# ```
````

#### last

````crystal
def self.last : T?

# Description
# Executes the query and returns the last result.

# Returns
# [T?] Last model instance or nil

# Example
# ```crystal
# User.last
# ```
````

#### last!

````crystal
def self.last! : T

# Description
# Executes the query and returns the last result, raising if not found.

# Returns
# [T] Last model instance

# Raises
# [CQL::RecordNotFound] When no record is found

# Example
# ```crystal
# User.last!
# ```
````

#### each

````crystal
def self.each(&block : T -> _) : Nil

# Description
# Iterates over query results.

# Parameters
# - **block** [Block] Block to execute for each record

# Example
# ```crystal
# User.each { |user| puts user.name }
# ```
````

#### exists?

````crystal
def self.exists? : Bool
def self.exists?(conditions : Hash(String | Symbol, DB::Any | Array(DB::Any))) : Bool
def self.exists?(**fields) : Bool

# Description
# Checks if any records exist matching the query.

# Parameters
# - **conditions** [Hash] Conditions to check
# - **fields** [Hash] Named arguments for conditions

# Returns
# [Bool] True if records exist

# Example
# ```crystal
# User.exists?
# User.exists?(active: true)
# ```
````

#### empty?

````crystal
def self.empty? : Bool

# Description
# Checks if no records exist matching the query.

# Returns
# [Bool] True if no records exist

# Example
# ```crystal
# User.empty?
# ```
````

### Finder Methods

#### find

````crystal
def self.find(id : Pk) : T?

# Description
# Finds a record by primary key.

# Parameters
# - **id** [Pk] Primary key value

# Returns
# [T?] Model instance or nil

# Example
# ```crystal
# User.find(123)
# ```
````

#### find?

````crystal
def self.find?(id : Pk) : T?

# Description
# Alias for find method.

# Parameters
# - **id** [Pk] Primary key value

# Returns
# [T?] Model instance or nil

# Example
# ```crystal
# User.find?(123)
# ```
````

#### find!

````crystal
def self.find!(id : Pk) : T

# Description
# Finds a record by primary key, raising if not found.

# Parameters
# - **id** [Pk] Primary key value

# Returns
# [T] Model instance

# Raises
# [CQL::RecordNotFound] When record is not found

# Example
# ```crystal
# User.find!(123)
# ```
````

#### find_by

````crystal
def self.find_by(conditions : Hash(String | Symbol, DB::Any | Array(DB::Any))) : T?
def self.find_by(**fields) : T?

# Description
# Finds the first record matching the conditions.

# Parameters
# - **conditions** [Hash] Conditions to match
# - **fields** [Hash] Named arguments for conditions

# Returns
# [T?] Model instance or nil

# Example
# ```crystal
# User.find_by(email: "john@example.com")
# ```
````

#### find_by!

````crystal
def self.find_by!(conditions : Hash(String | Symbol, DB::Any | Array(DB::Any))) : T
def self.find_by!(**fields) : T

# Description
# Finds the first record matching the conditions, raising if not found.

# Parameters
# - **conditions** [Hash] Conditions to match
# - **fields** [Hash] Named arguments for conditions

# Returns
# [T] Model instance

# Raises
# [CQL::RecordNotFound] When no record is found

# Example
# ```crystal
# User.find_by!(email: "john@example.com")
# ```
````

### Batch Processing Methods

#### find_each

````crystal
def self.find_each(batch_size : Int32 = 1000, &block : T -> _) : Nil

# Description
# Processes records in batches to avoid memory issues.

# Parameters
# - **batch_size** [Int32] Number of records per batch
# - **block** [Block] Block to execute for each record

# Example
# ```crystal
# User.find_each(batch_size: 500) { |user| process_user(user) }
# ```
````

#### find_in_batches

````crystal
def self.find_in_batches(batch_size : Int32 = 1000, &block : Array(T) -> _) : Nil

# Description
# Processes records in batches, yielding arrays of records.

# Parameters
# - **batch_size** [Int32] Number of records per batch
# - **block** [Block] Block to execute for each batch

# Example
# ```crystal
# User.find_in_batches { |batch| process_batch(batch) }
# ```
````

### Utility Methods

#### pluck

````crystal
def self.pluck(*columns : Symbol, as as_kind = DB::Any) : Array(as_kind)

# Description
# Extracts specific column values from records.

# Parameters
# - **columns** [Symbol*] Columns to extract
# - **as** [Type] Type to cast results to

# Returns
# [Array(as_kind)] Array of column values

# Example
# ```crystal
# User.pluck(:name, :email)
# User.pluck(:id, as: Int64)
# ```
````

#### pick

````crystal
def self.pick(column : Symbol) : DB::Any?

# Description
# Extracts a single column value from the first record.

# Parameters
# - **column** [Symbol] Column to extract

# Returns
# [DB::Any?] Column value or nil

# Example
# ```crystal
# User.pick(:name)
# ```
````

#### ids

````crystal
def self.ids(as as_kind = Int64) : Array(as_kind)

# Description
# Extracts primary key values from records.

# Parameters
# - **as** [Type] Type to cast results to

# Returns
# [Array(as_kind)] Array of primary key values

# Example
# ```crystal
# User.ids
# User.ids(as: String)
# ```
````

#### maximum

````crystal
def self.maximum(column : Symbol) : DB::Any?

# Description
# Finds maximum value in the specified column.

# Parameters
# - **column** [Symbol] Column to find maximum

# Returns
# [DB::Any?] Maximum value or nil

# Example
# ```crystal
# User.maximum(:age)
# ```
````

#### minimum

````crystal
def self.minimum(column : Symbol) : DB::Any?

# Description
# Finds minimum value in the specified column.

# Parameters
# - **column** [Symbol] Column to find minimum

# Returns
# [DB::Any?] Minimum value or nil

# Example
# ```crystal
# User.minimum(:age)
# ```
````

#### average

````crystal
def self.average(column : Symbol) : Float64?

# Description
# Calculates average of values in the specified column.

# Parameters
# - **column** [Symbol] Column to average

# Returns
# [Float64?] Average value or nil

# Example
# ```crystal
# User.average(:age)
# ```
````

#### distinct

````crystal
def self.distinct(column : Symbol, as as_kind = DB::Any) : Array(as_kind)

# Description
# Returns distinct values from the specified column.

# Parameters
# - **column** [Symbol] Column to get distinct values from
# - **as** [Type] Type to cast results to

# Returns
# [Array(as_kind)] Array of distinct values

# Example
# ```crystal
# User.distinct(:role)
# ```
````

### Collection Methods

#### any?

````crystal
def self.any? : Bool

# Description
# Checks if any records exist.

# Returns
# [Bool] True if any records exist

# Example
# ```crystal
# User.any?
# ```
````

#### many?

````crystal
def self.many? : Bool

# Description
# Checks if more than one record exists.

# Returns
# [Bool] True if multiple records exist

# Example
# ```crystal
# User.many?
# ```
````

#### size

````crystal
def self.size : Int32

# Description
# Returns the number of records.

# Returns
# [Int32] Number of records

# Example
# ```crystal
# User.size
# ```
````

#### none

````crystal
def self.none : QueryBuilder(T)

# Description
# Returns a query builder that will return no results.

# Returns
# [QueryBuilder(T)] Query builder with no results

# Example
# ```crystal
# User.none.all # Returns empty array
# ```
````

## CRUD Operations

### Create Methods

#### create!

````crystal
def self.create!(attrs : Hash(Symbol, DB::Any)) : T
def self.create!(**fields) : T
def self.create!(record : T) : T

# Description
# Creates a new record and saves it to the database.

# Parameters
# - **attrs** [Hash] Attributes hash
# - **fields** [Hash] Named arguments for attributes
# - **record** [T] Model instance to create

# Returns
# [T] Created model instance

# Raises
# [CQL::ValidationError] When validation fails

# Example
# ```crystal
# User.create!(name: "John", email: "john@example.com")
# ```
````

#### find_or_create_by

````crystal
def self.find_or_create_by(**attributes) : T
def self.find_or_create_by(attributes : Hash(Symbol, DB::Any)) : T

# Description
# Finds a record by attributes or creates it if not found.

# Parameters
# - **attributes** [Hash] Attributes to find or create by

# Returns
# [T] Found or created model instance

# Example
# ```crystal
# User.find_or_create_by(email: "john@example.com", name: "John")
# ```
````

### Update Methods

#### update!

````crystal
def self.update!(id : Pk, attrs : Hash(Symbol, DB::Any)) : T
def self.update!(id : Pk, **attrs) : T
def self.update!(record : T) : T

# Description
# Updates a record by ID or instance.

# Parameters
# - **id** [Pk] Primary key value
# - **attrs** [Hash] Attributes to update
# - **record** [T] Model instance to update

# Returns
# [T] Updated model instance

# Raises
# [CQL::RecordNotFound] When record is not found
# [CQL::ValidationError] When validation fails

# Example
# ```crystal
# User.update!(123, name: "Jane")
# ```
````

#### update_by

````crystal
def self.update_by(conditions : Hash(Symbol, DB::Any), attrs : Hash(Symbol, DB::Any)) : Int32

# Description
# Updates records matching conditions.

# Parameters
# - **conditions** [Hash] Conditions to match
# - **attrs** [Hash] Attributes to update

# Returns
# [Int32] Number of updated records

# Example
# ```crystal
# User.update_by({active: true}, {status: "verified"})
# ```
````

#### update_all

````crystal
def self.update_all(attrs : Hash(Symbol, DB::Any)) : Int32

# Description
# Updates all records with the given attributes.

# Parameters
# - **attrs** [Hash] Attributes to update

# Returns
# [Int32] Number of updated records

# Example
# ```crystal
# User.update_all(updated_at: Time.utc)
# ```
````

### Delete Methods

#### delete!

````crystal
def self.delete!(id : Pk) : T
def self.delete_by!(**fields) : T
def self.delete_by!(fields : Hash(Symbol, DB::Any)) : T

# Description
# Deletes a record by ID or conditions.

# Parameters
# - **id** [Pk] Primary key value
# - **fields** [Hash] Conditions to match

# Returns
# [T] Deleted model instance

# Raises
# [CQL::RecordNotFound] When record is not found

# Example
# ```crystal
# User.delete!(123)
# User.delete_by!(email: "john@example.com")
# ```
````

#### delete_all

````crystal
def self.delete_all : Int32

# Description
# Deletes all records.

# Returns
# [Int32] Number of deleted records

# Example
# ```crystal
# User.delete_all
# ```
````

## Instance Methods

### Persistence Methods

#### save!

````crystal
def save! : Bool

# Description
# Saves the record to the database.

# Returns
# [Bool] True if saved successfully

# Raises
# [CQL::ValidationError] When validation fails

# Example
# ```crystal
# user = User.new(name: "John")
# user.save!
# ```
````

#### update!

````crystal
def update!(**attrs) : Bool
def update!(attrs : Hash(Symbol, DB::Any)) : Bool

# Description
# Updates the record with new attributes.

# Parameters
# - **attrs** [Hash] Attributes to update

# Returns
# [Bool] True if updated successfully

# Raises
# [CQL::ValidationError] When validation fails

# Example
# ```crystal
# user.update!(name: "Jane")
# ```
````

#### delete!

````crystal
def delete! : Bool

# Description
# Deletes the record from the database.

# Returns
# [Bool] True if deleted successfully

# Example
# ```crystal
# user.delete!
# ```
````

### Persistence State

#### persisted?

````crystal
def persisted? : Bool

# Description
# Checks if the record is persisted in the database.

# Returns
# [Bool] True if record is persisted

# Example
# ```crystal
# user.persisted?
# ```
````

#### new_record?

````crystal
def new_record? : Bool

# Description
# Checks if the record is new (not persisted).

# Returns
# [Bool] True if record is new

# Example
# ```crystal
# user.new_record?
# ```
````

#### destroyed?

````crystal
def destroyed? : Bool

# Description
# Checks if the record has been destroyed.

# Returns
# [Bool] True if record is destroyed

# Example
# ```crystal
# user.destroyed?
# ```
````

### Validation Methods

#### valid?

````crystal
def valid?(context = nil) : Bool

# Description
# Checks if the record is valid.

# Parameters
# - **context** [Symbol?] Validation context

# Returns
# [Bool] True if record is valid

# Example
# ```crystal
# user.valid?
# user.valid?(:create)
# ```
````

#### validate!

````crystal
def validate!(context = nil) : Bool

# Description
# Validates the record and raises an error if invalid.

# Parameters
# - **context** [Symbol?] Validation context

# Returns
# [Bool] True if record is valid

# Raises
# [CQL::ValidationError] When validation fails

# Example
# ```crystal
# user.validate!
# ```
````

#### errors

````crystal
def errors(context = nil) : Array(CQL::ActiveRecord::Error)

# Description
# Returns validation errors for the record.

# Parameters
# - **context** [Symbol?] Validation context

# Returns
# [Array(CQL::ActiveRecord::Error)] Array of validation errors

# Example
# ```crystal
# user.errors
# user.errors(:create)
# ```
````

### Callback Methods

#### run_callbacks

````crystal
def run_callbacks(type : Symbol) : Bool

# Description
# Runs callbacks of the specified type.

# Parameters
# - **type** [Symbol] Callback type

# Returns
# [Bool] True if callbacks completed successfully

# Example
# ```crystal
# user.run_callbacks(:save)
# ```
````

## Error Classes

### CQL::RecordNotFound

````crystal
class CQL::RecordNotFound < Exception
  # Description
  # Raised when a record is not found in the database.

  # Example
  # ```crystal
  # begin
  #   User.find!(999)
  # rescue CQL::RecordNotFound
  #   puts "User not found"
  # end
  # ```
end
````

### CQL::ValidationError

````crystal
class CQL::ValidationError < Exception
  # Description
  # Raised when model validation fails.

  # Example
  # ```crystal
  # begin
  #   User.create!(name: "")
  # rescue CQL::ValidationError => ex
  #   puts "Validation failed: #{ex.message}"
  # end
  # ```
end
````

## Best Practices

### Model Definition

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context AcmeDB, :users

  # Define attributes with proper types
  getter id : Int64?
  getter name : String
  getter email : String
  getter age : Int32?
  getter active : Bool
  getter created_at : Time
  getter updated_at : Time

  # Define validations
  validates :name, presence: true, length: {minimum: 2, maximum: 100}
  validates :email, presence: true, format: /@/
  validates :age, numericality: {greater_than: 0, less_than: 120}

  # Define callbacks
  before_save :normalize_email
  after_create :send_welcome_email

  # Define relationships
  has_many :posts, Post, foreign_key: :user_id

  # Constructor
  def initialize(@name : String, @email : String, @age : Int32? = nil, @active : Bool = true)
    @created_at = Time.utc
    @updated_at = Time.utc
  end

  private def normalize_email
    @email = @email.downcase
  end

  private def send_welcome_email
    # Send welcome email logic
  end
end
```

### Query Optimization

```crystal
# Use specific columns instead of *
User.select(:name, :email).all

# Add appropriate limits
User.limit(1000).all

# Use indexes effectively
User.where(active: true).order(:created_at).all

# Use batch processing for large datasets
User.find_each(batch_size: 500) { |user| process_user(user) }
```

### Error Handling

```crystal
# Handle common errors
begin
  user = User.find!(123)
  user.update!(name: "New Name")
rescue CQL::RecordNotFound
  puts "User not found"
rescue CQL::ValidationError => ex
  puts "Validation failed: #{ex.message}"
rescue CQL::Error => ex
  puts "Database error: #{ex.message}"
end
```

This API reference provides comprehensive documentation for all Active Record functionality in CQL. Use it alongside the guides for practical examples and best practices.
