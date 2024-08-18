# Installation

To get started with CQL in your Crystal project, follow these steps:

## Step 1: Add Dependency

First, add CQL to your project by including it in the `shard.yml` file:

```yaml
dependencies:
  cql:
    github: azutoolkit/cql
    version: "~> 0.1.0"
```

## Step 2: Install Shards

Run the following command to install the dependencies:

```bash
shards install
```

## Step 3: Configure Database

Set up your database connection by specifying the adapter and connection URL. This is done by configuring the database in your code, as follows:

```crystal
"postgres://user:password@localhost:5432/database_name"
```

In this example, we’re using PostgreSQL. You can change the URL according to your database (MySQL, SQLite, etc.).

## Step 4: Create the Schema

Now you can define your schema and run migrations (explained in later sections).
