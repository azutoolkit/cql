---
description: >-
  Complete API reference for CQL's Query Builder - query construction, filtering, joins, aggregations, and execution methods.
---

# Query Builder API Reference

This reference documents all methods and features available in CQL's Query Builder system.

## CQL::Query

The main query builder class that provides a fluent interface for constructing SQL queries.

````crystal
class CQL::Query
  # Description
  # The Query class is responsible for building SQL queries in a structured manner.
  # It holds various components like selected columns, tables, conditions, and more.
  # It provides methods to execute the query and return results.

  # Features
  # - Type-safe query construction with compile-time checks
  # - Fluent interface for building complex queries
  # - Multiple database support (PostgreSQL, MySQL, SQLite)
  # - Automatic parameter binding for security
  # - Query optimization and caching capabilities
  # - Integration with Active Record patterns

  # Example
  # ```crystal
  # schema = CQL::Schema.new
  # query = CQL::Query.new(schema)
  # users = query.select(:name, :email).from(:users).where(active: true).all(User)
  # ```
end
````

## Constructor

### initialize

````crystal
def initialize(@schema : Schema)

# Description
# Initializes the Query object with the provided schema.

# Parameters
# - **schema** [Schema] The schema object to use for the query

# Returns
# [Query] The query object

# Example
# ```crystal
# schema = CQL::Schema.new
# query = CQL::Query.new(schema)
# ```
````

## Query Execution Methods

### all

````crystal
def all(as as_kind) : Array(as_kind)

# Description
# Executes the query and returns all records.

# Parameters
# - **as** [Type] The type to cast the results to

# Returns
# [Array(Type)] The results of the query

# Example
# ```crystal
# users = query.select(:name, :age).from(:users).all(User)
# ```
````

### all!

````crystal
def all!(as as_kind) : Array(as_kind)

# Description
# Executes the query and returns all records, raising if nil.

# Parameters
# - **as** [Type] The type to cast the results to

# Returns
# [Array(Type)] The results of the query

# Raises
# [Exception] When result is nil

# Example
# ```crystal
# users = query.select(:name, :age).from(:users).all!(User)
# ```
````

### first

````crystal
def first(as as_kind) : as_kind?

# Description
# Executes the query and returns the first record.

# Parameters
# - **as** [Type] The type to cast the result to

# Returns
# [Type?] The first result of the query or nil

# Example
# ```crystal
# user = query.select(:name, :age).from(:users).first(User)
# ```
````

### first!

````crystal
def first!(as as_kind) : as_kind

# Description
# Executes the query and returns the first record, raising if not found.

# Parameters
# - **as** [Type] The type to cast the result to

# Returns
# [Type] The first result of the query

# Raises
# [Exception] When no result is found

# Example
# ```crystal
# user = query.select(:name, :age).from(:users).first!(User)
# ```
````

### get

````crystal
def get(as as_kind) : as_kind?

# Description
# Executes the query and returns a scalar value.

# Parameters
# - **as** [Type] The type to cast the result to

# Returns
# [Type?] The scalar result of the query

# Example
# ```crystal
# count = query.select(:count).from(:users).get(Int64)
# ```
````

### each

````crystal
def each(as as_kind, &block : as_kind -> _) : Nil

# Description
# Iterates over each result and yields it to the provided block.

# Parameters
# - **as** [Type] The type to cast the results to
# - **block** [Block] Block to execute for each result

# Example
# ```crystal
# query.select(:name, :age).from(:users).each(User) do |user|
#   puts user.name
# end
# ```
````

## Query Construction Methods

### select

````crystal
def select(*columns : Symbol | String) : Query
def select(**fields : Hash(String | Symbol, Array(Symbol) | Symbol)) : Query
def select(*cols : Symbol | String, **fields : Hash(String | Symbol, Array(Symbol) | Symbol)) : Query

# Description
# Specifies which columns to select from the query.

# Parameters
# - **columns** [Symbol | String*] Column names to select
# - **fields** [Hash] Hash-based column selection with table prefixes

# Returns
# [Query] The query object for chaining

# Example
# ```crystal
# query.select(:name, :email).from(:users)
# query.select(users: [:name], posts: [:title]).from(:users, :posts)
# ```
````

### from

````crystal
def from(*tbls_or_aliases : Symbol | Hash(Symbol, Symbol)) : Query
def from(**tables_with_aliases) : Query

# Description
# Specifies the tables to query from.

# Parameters
# - **tbls_or_aliases** [Symbol | Hash*] Table names or name => alias mappings
# - **tables_with_aliases** [Hash] Named arguments for table name => alias

# Returns
# [Query] The query object for chaining

# Example
# ```crystal
# query.from(:users)
# query.from(users: :u, posts: :p)
# ```
````

### where

````crystal
def where(hash : Hash(String | Symbol, DB::Any | Array(DB::Any))) : Query
def where(&block : Expression::FilterBuilder -> _) : Query
def where(**fields) : Query

# Description
# Adds WHERE conditions to the query.

# Parameters
# - **hash** [Hash] Conditions hash
# - **block** [Block] Block for complex conditions
# - **fields** [Hash] Named arguments for conditions

# Returns
# [Query] The query object for chaining

# Example
# ```crystal
# query.from(:users).where(active: true)
# query.from(:users).where { |f| f.gt(:age, 18) }
# ```
````

### where_like

````crystal
def where_like(field : Symbol | String, pattern : String) : Query

# Description
# Adds a LIKE condition to the query.

# Parameters
# - **field** [Symbol | String] Field name to match
# - **pattern** [String] SQL LIKE pattern

# Returns
# [Query] The query object for chaining

# Example
# ```crystal
# query.from(:users).where_like(:name, "John%")
# ```
````

## Join Methods

### join

````crystal
def join(table_or_alias : Symbol) : Query
def join(table_or_alias : Symbol, &block : Expression::FilterBuilder -> _) : Query
def join(**tables_with_aliases) : Query

# Description
# Adds an INNER JOIN to the query.

# Parameters
# - **table_or_alias** [Symbol] Table name or alias
# - **block** [Block] Block for join conditions
# - **tables_with_aliases** [Hash] Table name => alias mapping

# Returns
# [Query] The query object for chaining

# Example
# ```crystal
# query.from(:users).join(:posts)
# query.from(:users).join(:posts) { |j| j.on(:user_id, :id) }
# ```
````

### left

````crystal
def left(table_or_alias : Symbol) : Query
def left(table_or_alias : Symbol, &block : Expression::FilterBuilder -> _) : Query
def left(**tables_with_aliases) : Query

# Description
# Adds a LEFT JOIN to the query.

# Parameters
# - **table_or_alias** [Symbol] Table name or alias
# - **block** [Block] Block for join conditions
# - **tables_with_aliases** [Hash] Table name => alias mapping

# Returns
# [Query] The query object for chaining

# Example
# ```crystal
# query.from(:users).left(:profiles)
# ```
````

### right

````crystal
def right(table_or_alias : Symbol) : Query
def right(table_or_alias : Symbol, &block : Expression::FilterBuilder -> _) : Query
def right(**tables_with_aliases) : Query

# Description
# Adds a RIGHT JOIN to the query.

# Parameters
# - **table_or_alias** [Symbol] Table name or alias
# - **block** [Block] Block for join conditions
# - **tables_with_aliases** [Hash] Table name => alias mapping

# Returns
# [Query] The query object for chaining

# Example
# ```crystal
# query.from(:users).right(:profiles)
# ```
````

## Ordering and Grouping

### order

````crystal
def order(*fields : Symbol | String) : Query
def order(**fields) : Query

# Description
# Adds ORDER BY clauses to the query.

# Parameters
# - **fields** [Symbol | String*] Fields to order by
# - **fields** [Hash] Hash-based ordering with directions

# Returns
# [Query] The query object for chaining

# Example
# ```crystal
# query.from(:users).order(:name)
# query.from(:users).order(name: :asc, created_at: :desc)
# ```
````

### group

````crystal
def group(*columns : Symbol | String) : Query

# Description
# Adds GROUP BY clauses to the query.

# Parameters
# - **columns** [Symbol | String*] Columns to group by

# Returns
# [Query] The query object for chaining

# Example
# ```crystal
# query.from(:users).group(:role).count
# ```
````

### having

````crystal
def having(&block : Expression::HavingBuilder -> _) : Query

# Description
# Adds HAVING conditions to the query.

# Parameters
# - **block** [Block] Block for HAVING conditions

# Returns
# [Query] The query object for chaining

# Example
# ```crystal
# query.from(:users).group(:role).having { |h| h.gt(:count, 5) }
# ```
````

## Limiting and Pagination

### limit

````crystal
def limit(value : Int32) : Query

# Description
# Adds a LIMIT clause to the query.

# Parameters
# - **value** [Int32] Maximum number of results

# Returns
# [Query] The query object for chaining

# Example
# ```crystal
# query.from(:users).limit(10)
# ```
````

### offset

````crystal
def offset(value : Int32) : Query

# Description
# Adds an OFFSET clause to the query.

# Parameters
# - **value** [Int32] Number of results to skip

# Returns
# [Query] The query object for chaining

# Example
# ```crystal
# query.from(:users).offset(20).limit(10)
# ```
````

## Distinct and Reordering

### distinct

````crystal
def distinct : Query

# Description
# Adds a DISTINCT clause to the query.

# Returns
# [Query] The query object for chaining

# Example
# ```crystal
# query.from(:users).select(:role).distinct
# ```
````

### reorder

````crystal
def reorder(*fields : Symbol | String) : Query
def reorder(**fields) : Query

# Description
# Replaces existing ORDER BY clauses with new ones.

# Parameters
# - **fields** [Symbol | String*] Fields to order by
# - **fields** [Hash] Hash-based ordering with directions

# Returns
# [Query] The query object for chaining

# Example
# ```crystal
# query.from(:users).order(:name).reorder(:created_at, :desc)
# ```
````

### reverse_order

````crystal
def reverse_order : Query

# Description
# Reverses the current ORDER BY clauses.

# Returns
# [Query] The query object for chaining

# Example
# ```crystal
# query.from(:users).order(:name, :created_at).reverse_order
# ```
````

## Aggregation Methods

### count

````crystal
def count(column : Symbol = :*) : Query

# Description
# Adds a COUNT aggregate function to the query.

# Parameters
# - **column** [Symbol] The column to count (default: :*)

# Returns
# [Query] The query object for chaining

# Example
# ```crystal
# query.from(:users).count
# query.from(:users).count(:id)
# ```
````

### sum

````crystal
def sum(column : Symbol) : Query

# Description
# Adds a SUM aggregate function to the query.

# Parameters
# - **column** [Symbol] The column to sum

# Returns
# [Query] The query object for chaining

# Example
# ```crystal
# query.from(:users).sum(:score)
# ```
````

### avg

````crystal
def avg(column : Symbol) : Query

# Description
# Adds an AVG aggregate function to the query.

# Parameters
# - **column** [Symbol] The column to average

# Returns
# [Query] The query object for chaining

# Example
# ```crystal
# query.from(:users).avg(:age)
# ```
````

### min

````crystal
def min(column : Symbol) : Query

# Description
# Adds a MIN aggregate function to the query.

# Parameters
# - **column** [Symbol] The column to find minimum

# Returns
# [Query] The query object for chaining

# Example
# ```crystal
# query.from(:users).min(:age)
# ```
````

### max

````crystal
def max(column : Symbol) : Query

# Description
# Adds a MAX aggregate function to the query.

# Parameters
# - **column** [Symbol] The column to find maximum

# Returns
# [Query] The query object for chaining

# Example
# ```crystal
# query.from(:users).max(:age)
# ```
````

## Query Management

### unscope

````crystal
def unscope(*scopes : Symbol) : Query

# Description
# Removes specified scopes from the query.

# Parameters
# - **scopes** [Symbol*] Scope names to remove

# Returns
# [Query] The query object for chaining

# Example
# ```crystal
# query.from(:users).where(active: true).unscope(:where)
# ```
````

### merge

````crystal
def merge(other_query : Query) : Query

# Description
# Merges another query into this one.

# Parameters
# - **other_query** [Query] Query to merge

# Returns
# [Query] Merged query object

# Example
# ```crystal
# query1 = query.from(:users).where(active: true)
# query2 = query.from(:users).where(admin: true)
# merged = query1.merge(query2)
# ```
````

## SQL Generation

### to_sql

````crystal
def to_sql(gen = @schema.gen) : {String, Array(DB::Any)}

# Description
# Generates the SQL string and parameters for the query.

# Parameters
# - **gen** [SQLGenerator] SQL generator instance

# Returns
# [{String, Array(DB::Any)}] Tuple of SQL string and parameters

# Example
# ```crystal
# sql, params = query.from(:users).where(active: true).to_sql
# puts "SQL: #{sql}"
# puts "Params: #{params}"
# ```
````

### build

````crystal
def build : Query

# Description
# Builds the query and returns it for execution.

# Returns
# [Query] Built query object

# Example
# ```crystal
# query.from(:users).where(active: true).build.all(User)
# ```
````

## Query Builder Classes

### QueryBuilder(T)

A specialized query builder for Active Record models.

````crystal
class QueryBuilder(T)
  # Description
  # A query builder that provides type-safe querying for Active Record models.

  # Features
  # - Type-safe model integration
  # - Automatic type casting
  # - Model-specific optimizations
  # - Caching capabilities

  # Example
  # ```crystal
  # builder = User.query.where(active: true)
  # users = builder.all
  # ```
end
````

#### from_model

````crystal
def self.from_model(model_class : T.class) : QueryBuilder(T) forall T

# Description
# Creates a query builder for a specific model class.

# Parameters
# - **model_class** [T.class] The model class

# Returns
# [QueryBuilder(T)] Query builder for the model

# Example
# ```crystal
# builder = QueryBuilder(User).from_model(User)
# ```
````

#### cache

````crystal
def cache(enabled : Bool = true) : QueryBuilder(T)

# Description
# Enables or disables query caching.

# Parameters
# - **enabled** [Bool] Whether to enable caching

# Returns
# [QueryBuilder(T)] The query builder for chaining

# Example
# ```crystal
# User.query.cache(true).where(active: true).all
# ```
````

#### cache_enabled?

````crystal
def cache_enabled? : Bool

# Description
# Checks if query caching is enabled.

# Returns
# [Bool] True if caching is enabled

# Example
# ```crystal
# if builder.cache_enabled?
#   # Use cached results
# end
# ```
````

## Expression Classes

### Expression::FilterBuilder

Provides methods for building complex filter conditions.

````crystal
class Expression::FilterBuilder
  # Description
  # Builder class for creating complex WHERE conditions.

  # Example
  # ```crystal
  # query.from(:users).where do |filter|
  #   filter.eq(:active, true)
  #         .and
  #         .gt(:age, 18)
  # end
  # ```
end
````

#### eq

````crystal
def eq(field : Symbol | String, value : T) : FilterBuilder forall T

# Description
# Adds an equality condition.

# Parameters
# - **field** [Symbol | String] Field name
# - **value** [T] Value to compare

# Returns
# [FilterBuilder] The filter builder for chaining

# Example
# ```crystal
# filter.eq(:status, "active")
# ```
````

#### not_eq

````crystal
def not_eq(field : Symbol | String, value : T) : FilterBuilder forall T

# Description
# Adds a not-equal condition.

# Parameters
# - **field** [Symbol | String] Field name
# - **value** [T] Value to compare

# Returns
# [FilterBuilder] The filter builder for chaining

# Example
# ```crystal
# filter.not_eq(:status, "inactive")
# ```
````

#### gt

````crystal
def gt(field : Symbol | String, value : T) : FilterBuilder forall T

# Description
# Adds a greater-than condition.

# Parameters
# - **field** [Symbol | String] Field name
# - **value** [T] Value to compare

# Returns
# [FilterBuilder] The filter builder for chaining

# Example
# ```crystal
# filter.gt(:age, 18)
# ```
````

#### gte

````crystal
def gte(field : Symbol | String, value : T) : FilterBuilder forall T

# Description
# Adds a greater-than-or-equal condition.

# Parameters
# - **field** [Symbol | String] Field name
# - **value** [T] Value to compare

# Returns
# [FilterBuilder] The filter builder for chaining

# Example
# ```crystal
# filter.gte(:score, 100)
# ```
````

#### lt

````crystal
def lt(field : Symbol | String, value : T) : FilterBuilder forall T

# Description
# Adds a less-than condition.

# Parameters
# - **field** [Symbol | String] Field name
# - **value** [T] Value to compare

# Returns
# [FilterBuilder] The filter builder for chaining

# Example
# ```crystal
# filter.lt(:age, 65)
# ```
````

#### lte

````crystal
def lte(field : Symbol | String, value : T) : FilterBuilder forall T

# Description
# Adds a less-than-or-equal condition.

# Parameters
# - **field** [Symbol | String] Field name
# - **value** [T] Value to compare

# Returns
# [FilterBuilder] The filter builder for chaining

# Example
# ```crystal
# filter.lte(:balance, 1000)
# ```
````

#### like

````crystal
def like(field : Symbol | String, pattern : String) : FilterBuilder

# Description
# Adds a LIKE condition.

# Parameters
# - **field** [Symbol | String] Field name
# - **pattern** [String] SQL LIKE pattern

# Returns
# [FilterBuilder] The filter builder for chaining

# Example
# ```crystal
# filter.like(:name, "%John%")
# ```
````

#### in

````crystal
def in(field : Symbol | String, values : Array(T)) : FilterBuilder forall T

# Description
# Adds an IN condition.

# Parameters
# - **field** [Symbol | String] Field name
# - **values** [Array(T)] Values to match

# Returns
# [FilterBuilder] The filter builder for chaining

# Example
# ```crystal
# filter.in(:role, ["admin", "moderator"])
# ```
````

#### is_null

````crystal
def is_null(field : Symbol | String) : FilterBuilder

# Description
# Adds an IS NULL condition.

# Parameters
# - **field** [Symbol | String] Field name

# Returns
# [FilterBuilder] The filter builder for chaining

# Example
# ```crystal
# filter.is_null(:deleted_at)
# ```
````

#### is_not_null

````crystal
def is_not_null(field : Symbol | String) : FilterBuilder

# Description
# Adds an IS NOT NULL condition.

# Parameters
# - **field** [Symbol | String] Field name

# Returns
# [FilterBuilder] The filter builder for chaining

# Example
# ```crystal
# filter.is_not_null(:email)
# ```
````

#### and

````crystal
def and : FilterBuilder

# Description
# Adds an AND operator to the condition chain.

# Returns
# [FilterBuilder] The filter builder for chaining

# Example
# ```crystal
# filter.eq(:active, true).and.gt(:age, 18)
# ```
````

#### or

````crystal
def or : FilterBuilder

# Description
# Adds an OR operator to the condition chain.

# Returns
# [FilterBuilder] The filter builder for chaining

# Example
# ```crystal
# filter.eq(:role, "admin").or.eq(:role, "moderator")
# ```
````

#### group

````crystal
def group(&block : FilterBuilder -> _) : FilterBuilder

# Description
# Groups conditions with parentheses.

# Parameters
# - **block** [Block] Block containing grouped conditions

# Returns
# [FilterBuilder] The filter builder for chaining

# Example
# ```crystal
# filter.group do |g|
#   g.eq(:category, "tech").or.eq(:category, "science")
# end
# ```
````

### Expression::HavingBuilder

Provides methods for building HAVING conditions.

````crystal
class Expression::HavingBuilder
  # Description
  # Builder class for creating HAVING conditions in grouped queries.

  # Example
  # ```crystal
  # query.from(:users).group(:role).having do |having|
  #   having.gt(:count, 5)
  # end
  # ```
end
````

The HavingBuilder provides the same methods as FilterBuilder for building HAVING conditions.

## Best Practices

### Query Construction

```crystal
# Build queries incrementally
base_query = query.from(:users).where(active: true)

# Add conditions based on logic
if admin_only
  base_query = base_query.where(admin: true)
end

if age_filter
  base_query = base_query.where(age: 18..65)
end

users = base_query.order(:name).all(User)
```

### Performance Optimization

```crystal
# Use specific columns instead of *
query.select(:name, :email).from(:users).all(User)

# Add appropriate limits
query.from(:users).limit(1000).all(User)

# Use indexes effectively
query.from(:users).where(active: true).order(:created_at).all(User)
```

### Error Handling

```crystal
begin
  users = query.from(:users).all(User)
rescue CQL::Error => ex
  puts "Query error: #{ex.message}"
end
```

### Query Analysis

```crystal
# Get the generated SQL for analysis
sql, params = query.from(:users)
                   .where(active: true)
                   .order(:name)
                   .to_sql

puts "Generated SQL: #{sql}"
puts "Parameters: #{params}"
```

This API reference provides comprehensive documentation for all Query Builder functionality in CQL. Use it alongside the guides for practical examples and best practices.
