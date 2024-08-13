[![Crystal CI](https://github.com/azutoolkit/cql/actions/workflows/crystal.yml/badge.svg)](https://github.com/azutoolkit/cql/actions/workflows/crystal.yml)

# CQL Toolkit

CQL Toolkit is a powerful library designed to simplify and enhance the management and execution of SQL queries in the Crystal programming language. It provides utilities for building, validating, and executing SQL statements, ensuring better performance and code maintainability.

## Table of Contents

- [CQL Toolkit](#cql-toolkit)
  - [Table of Contents](#table-of-contents)
  - [Features](#features)
  - [Installation](#installation)
  - [Getting Started](#getting-started)
    - [1. Define a Schema](#1-define-a-schema)
    - [2. Executing Queries](#2-executing-queries)
    - [3. Inserting Data](#3-inserting-data)
    - [4. Updating Data](#4-updating-data)
    - [5. Deleting Data](#5-deleting-data)
    - [6. Using the Repository Pattern](#6-using-the-repository-pattern)
    - [7. Active Record Pattern](#7-active-record-pattern)
  - [Documentation](#documentation)
  - [Contributing](#contributing)
  - [License](#license)
  - [Acknowledgments](#acknowledgments)

## Features

- **Query Builder**: Programmatically create complex SQL queries.
- **Insert, Update, Delete Operations**: Perform CRUD operations with ease.
- **Repository Pattern**: Manage your data more effectively using `Cql::Repository(T)`.
- **Active Record Pattern**: Work with your data models using `Cql::Record(T)`.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  cql:
    github: azutoolkit/cql
```

Then, run the following command to install the dependencies:

```bash
shards install
```

## Getting Started

### 1. Define a Schema

Define the schema for your database tables:

```crystal
schema = Cql::Schema.build(
  :my_database,
  adapter: Cql::Adapter::Postgres,
  db: DB.open("postgresql://user:password@localhost:5432/database_name")
  ) do

  table :users do
    primary_key :id, Int64, auto_increment: true
    column :name, String
    column :email, String
  end
end
```

### 2. Executing Queries

With the schema in place, you can start executing queries:

```crystal
q = Cql::Query.new(schema)

user = q.from(:users).where(id: 1).first(as: User)

puts user.name if user
```

### 3. Inserting Data

Insert new records into the database:

```crystal
q = Cql::Query.new(schema)

q.insert_into(:users, name: "Jane Doe", email: "jane@example.com")
```

### 4. Updating Data

Update existing records:

```crystal
q = Cql::Query.new(schema)

q.update(:users).set(name: "Jane Smith").where(id: 1)
```

### 5. Deleting Data

Delete records from the database:

```crystal
q = Cql::Query.new(schema)

q.delete_from(:users).where(id: 1)
```

### 6. Using the Repository Pattern

Utilize the repository pattern for organized data management:

```crystal
user_repository = Cql::Repository(User).new(schema, :users)

# Create a new user
user_repository.create(id: 1, name: "Jane Doe", email: "jane@example.com")

# Fetch all users
users = user_repository.all
users.each { |user| puts user.name }

# Find a user by ID
user = user_repository.find!(1)
puts user.name

# Update a user by ID
user_repository.update(1, name: "Jane Smith")
```

### 7. Active Record Pattern

Work with your data using the Active Record pattern:

```crystal
AcmeDB = Cql::Schema.build(...) do ... end

struct User
  include Cql::Record(User)
  define schema: AcmeDB, table: :users

  # Crystal properties (no macros)
  property id : Int64
  property name : String
  property email : String
end

user = User.find(1)
user.name = "Jane Smith"
user.save
```

## Documentation

Detailed API documentation is available at [CQL Documentation](https://azutoolkit.github.io/cql/).

## Contributing

Contributions are welcome! To contribute:

1. Fork this repository.
2. Create your feature branch: `git checkout -b my-new-feature`.
3. Commit your changes: `git commit -am 'Add some feature'`.
4. Push to the branch: `git push origin my-new-feature`.
5. Create a new Pull Request.

## License

This project is licensed under the MIT License. See the [LICENSE](./LICENSE) file for details.

## Acknowledgments

Thanks to all the contributors who helped in the development of this project.
