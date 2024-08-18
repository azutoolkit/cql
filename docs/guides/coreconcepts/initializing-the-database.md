# Initializing the Database

Once you've defined your database schema using CQL's `Schema.build`, the next step is to initialize the database by creating the necessary tables and structures. In this guide, we will walk through how to define your schema and use `Schema.init` to initialize the database.

***

### Real-World Example: Defining the Database Schema

Here’s an example where we define a schema for a movie database using CQL. The schema includes tables for `movies`, `screenplays`, `actors`, `directors`, and a join table `movies_actors` to link movies and actors.

```crystal
AcmeDB2 = Cql::Schema.build(
  :acme_db,
  adapter: Cql::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]
) do
  table :movies do
    primary :id, Int64, auto_increment: true
    text :title
  end

  table :screenplays do
    primary :id, Int64, auto_increment: true
    bigint :movie_id
    text :content
  end

  table :actors do
    primary :id, Int64, auto_increment: true
    text :name
  end

  table :directors do
    primary :id, Int64, auto_increment: true
    bigint :movie_id
    text :name
  end

  table :movies_actors do
    primary :id, Int64, auto_increment: true
    bigint :movie_id
    bigint :actor_id
  end
end
```

### Explanation

In the example above, we define:

* **`movies`**: Stores information about movies, including an auto-incrementing `id` and a `title`.
* **`screenplays`**: Stores the screenplay contents for movies, linking to the `movies` table with `movie_id`.
* **`actors`**: Stores actor names, with an auto-incrementing `id`.
* **`directors`**: Stores director names, associated with a movie via `movie_id`.
* **`movies_actors`**: A join table to link `movies` and `actors`, establishing a many-to-many relationship between movies and actors.

***

### Initializing the Database

Once the schema has been defined, the next step is to initialize the database. This is done by calling the `Schema.init` method (or in our case, `AcmeDB2.init`), which creates the tables based on the schema.

#### Steps to Initialize

1. **Set up the environment**: Ensure that the `DATABASE_URL` environment variable is correctly set to point to your database connection string (for PostgreSQL in this case).
2. **Call `Schema.init`**: After defining the schema, you initialize the database by calling the `init` method on the schema object.

```crystal
AcmeDB2.init
```

This command creates all the tables and applies the structure you defined in the schema to your actual database.

***

### Full Example: Defining and Initializing the Database

```crystal
# Define the schema
AcmeDB2 = Cql::Schema.build(
  :acme_db,
  adapter: Cql::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]
) do
  table :movies do
    primary :id, Int64, auto_increment: true
    text :title
  end

  table :screenplays do
    primary :id, Int64, auto_increment: true
    bigint :movie_id
    text :content
  end

  table :actors do
    primary :id, Int64, auto_increment: true
    text :name
  end

  table :directors do
    primary :id, Int64, auto_increment: true
    bigint :movie_id
    text :name
  end

  table :movies_actors do
    primary :id, Int64, auto_increment: true
    bigint :movie_id
    bigint :actor_id
  end
end

# Initialize the database
AcmeDB2.init
```

### Generated Database Tables&#x20;

<figure><img src="../../.gitbook/assets/Untitled (1).svg" alt=""><figcaption></figcaption></figure>

#### What Happens During Initialization?

When `AcmeDB2.init` is called, the following happens:

* The database connection is established using the URI provided in the schema (e.g., the PostgreSQL database connection).
* CQL creates the tables (`movies`, `screenplays`, `actors`, `directors`, and `movies_actors`) in the database if they don’t already exist.
* Primary keys, relationships, and any constraints are applied as defined in the schema.

***

### Verifying the Initialization

After calling `AcmeDB2.init`, you can verify the tables are created in your database by using a PostgreSQL client or a GUI tool such as `pgAdmin`. You should see the tables with their respective columns and relationships as defined in the schema.

```sql
-- Example SQL to verify the tables were created
SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';

-- To check the structure of a table, use:
\d movies  -- This shows the structure of the 'movies' table
```

***

### Summary

Initializing the database after schema creation is a simple process with CQL. After defining your tables and relationships using `Cql::Schema.build`, you can call the `init` method to apply your schema to the actual database.

This method ensures that your database is correctly structured and ready to use, allowing you to focus on developing the application logic without worrying about manual database setup.

```crystal
AcmeDB2.init  # Initializes the schema and sets up the database
```
