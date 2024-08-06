# SQL Toolkit

SQL Toolkit is a comprehensive library designed to simplify and enhance the management and execution of SQL queries in Crystal. This toolkit provides utilities for building, validating, and executing SQL statements with ease, ensuring better performance and code maintainability.

## Features

- **Query Builder:** Create complex SQL queries programmatically.
- **Connection Management:** Simplify the management of database connections.
- **Parameter Binding:** Securely bind parameters to avoid SQL injection.
- **Schema Inspection:** Inspect and interact with database schemas.
- **Transaction Support:** Handle database transactions with ease.
- **Cross-Database Compatibility:** Supports multiple databases like PostgreSQL, MySQL, SQLite, and more.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  sql:
    github: azutoolkit/sql
```

Then run `shards install` to install the dependencies.

## Usage

### Connecting to a Database and Defining a Schema

```crystal
require "cql"

connection = DB.connect("postgresql://example:example@localhost:5432/example")
schema = Cql::Schema.new(:northwind, adapter: Cql::Adapter::Postgres, db: connection, version: "1.0")

```

### Registering Tables

```crystal
Schema.table :users do
  primary_key :id, Int64, auto_increment: true
  column :name, String
  column :email, String
end

Schema.table :addresses do
  primary_key :id, Int64, auto_increment: true
  column :user_id, Int64
  column :address, String
end
```

### Executing Queries

```crystal

struct User
  include DB::Serializable

  getter id : Int64
  getter name : String
  getter email : String

  def initialize(@id, @name, @email)
  end
end

q = Cql::Query.new(schema)

user_id = 1
user = q.from(:users).where(id: user_id).first(as: User)

=> user.id
~> 1
```

### Using the Query Builder

Define Schema

```crystal
Schema = Cql::Schema.new(:northwind)

Schema.table :customers do
  primary :customer_id, Int64, auto_increment: true
  column :name, String
  column :city, String
  column :balance, Int64
end

Schema.table :users do
  primary :id, Int64, auto_increment: true
  column :name, String
  column :email, String
end

Schema.table :address do
  primary :id, Int64, auto_increment: true
  column :user_id, Int64, null: false
  column :street, String
  column :city, String
  column :zip, String
end

Schema.table :employees do
  primary :id, Int64, auto_increment: true
  column :name, String
  column :email, String
  column :phone, String
  column :department, String
end
```

```crystal

struct User
  include DB::Serializable

  getter id : Int64
  getter name : String
  getter email : String
  getter addresses : Array(Address)

  def initialize(@id, @name, @email, @addresses)
  end
end

struct Address
  include DB::Serializable

  getter id : Int64
  getter street : String
  getter city : String

  def initialize(@id, @street, @city)
  end
end

q = Cql::Query.new(Schema)

query = q.from(:users)
      .select(users: [:name, :email], address: [:street, :city])
      .inner(:address) do
        (users.id.eq(address.user_id)) & (users.name.eq("'John'")) | (users.id.eq(1))
      end

query.each(as: User) do |user|
  puts user
end

result.each do |row|
  puts row["users.name"]
end
```

### Using the Repository Pattern

```crystal
struct User
  include DB::Serializable
  getter id : Int64
  getter name : String
  getter email : String

  def initialize(@id : Int64, @name : String, @email : String)
  end
end
```

Use the repository:

```crystal
user_repository = Cql::Repository(User).new(schema, :users)

# Create a new user
user_repository.create(id: 1_i64, name: "John Doe", email: "john@example.com")

# Fetch all users
users = user_repository.all
users.each do |user|
  puts user.name
end

# Find a user by ID
user = user_repository.find!(1_i64)
puts user.name

# Update a user by ID
user_repository.update(1_i64, name: "John Smith")
```

## Documentation

Detailed documentation can be found [here](https://github.com/azutoolkit/sql/wiki).

## Contributing

1. Fork it (<https://github.com/azutoolkit/sql/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

Thanks to all the contributors who have helped in the development of this project.
