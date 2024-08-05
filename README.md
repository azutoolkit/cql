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

### Connecting to a Database

```crystal
require "sql"

db = Cql.connect("postgres://user:password@localhost/db_name")
```

### Executing Queries

```crystal
Schema = Cql::Schema.new(:northwind)

schema = Schema.table :users do
  primary_key :id, Int64, auto_increment: true
  column :name, String
  column :email, String
end

q = Cql::Query.new(schema)

result = db.execute(
  q.from(:users).where(id: "?"),
  1
)

result.each do |row|
  puts row["name"]
end
```

### Using the Query Builder

Define Schema

```crystal
Schema = Cql::Schema.new(:northwind)

Schema.table :customers do
  primary_key :customer_id, Int64, auto_increment: true
  column :name, String
  column :city, String
  column :balance, Int64
end

Schema.table :users do
  primary_key :id, Int64, auto_increment: true
  column :name, String
  column :email, String
end

Schema.table :address do
  primary_key :id, Int64, auto_increment: true
  column :user_id, Int64, null: false
  column :street, String
  column :city, String
  column :zip, String
end

Schema.table :employees do
  primary_key :id, Int64, auto_increment: true
  column :name, String
  column :email, String
  column :phone, String
  column :department, String
end
```

```crystal
q = Cql::Query.new(Schema)

query = q
      .from(:users)
      .select(users: [:name, :email], address: [:street, :city])
      .inner(:address) do
        (users.id.eq(address.user_id)) & (users.name.eq("'John'")) | (users.id.eq(1))
      end.to_sql


result = db.execute(query)

result.each do |row|
  puts row["users.name"]
end
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
