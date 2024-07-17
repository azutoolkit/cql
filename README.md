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
require "sql_toolkit"

db = SQLToolkit::Database.new("postgres://user:password@localhost/db_name")
```

### Executing Queries

```crystal
result = db.execute("SELECT * FROM users WHERE id = ?", 1)

result.each do |row|
  puts row["name"]
end
```

### Using the Query Builder

```crystal
query = Sql.q
          .select("*")
          .from("users")
          .where("age > ?", 18)
          .order_by("name")
          .to_sql

result = db.execute(query)

result.each do |row|
  puts row["name"]
end
```

### Transactions

```crystal
db.transaction do |tx|
  tx.execute("INSERT INTO users (name, age) VALUES (?, ?)", "Alice", 30)
  tx.execute("INSERT INTO users (name, age) VALUES (?, ?)", "Bob", 25)
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
