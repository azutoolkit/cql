# Set Up Connection Pooling

Configure database connection pooling for better performance and resource management.

## Prerequisites

- CQL installed and configured
- Database connection working

## Basic Pool Configuration

Configure pool settings when defining your schema:

```crystal
MyDB = CQL::Schema.define(
  :my_db,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]
) do
  # Pool settings
  pool_size 25
  checkout_timeout 5.seconds
  retry_attempts 3
end
```

## Pool Settings

### pool_size

Maximum number of connections in the pool:

```crystal
pool_size 25  # Default: 5
```

**Guidelines:**
- Web apps: 2-3x your web server threads
- Background jobs: Match worker count
- Maximum: Check database limits

### checkout_timeout

How long to wait for an available connection:

```crystal
checkout_timeout 5.seconds  # Default: 5 seconds
```

If timeout is reached, raises `CQL::ConnectionTimeout`.

### retry_attempts

Number of times to retry failed connections:

```crystal
retry_attempts 3  # Default: 1
```

## Environment-Specific Configuration

```crystal
pool = case ENV["APP_ENV"]?
       when "production"  then 25
       when "staging"     then 10
       else                    5
       end

MyDB = CQL::Schema.define(:my_db, adapter: CQL::Adapter::Postgres, uri: db_url) do
  pool_size pool
end
```

## Monitoring Pool Health

```crystal
# Check current pool status
stats = MyDB.pool_stats
puts "Available: #{stats[:available]}"
puts "In use: #{stats[:busy]}"
puts "Size: #{stats[:size]}"
```

## Verify Configuration

Test your pool under load:

```crystal
# Simulate concurrent connections
10.times do
  spawn do
    User.count
    puts "Connection successful"
  end
end
sleep 1.second
```

## Common Issues

**Pool exhaustion:**
- Increase `pool_size`
- Reduce connection hold time
- Use transactions efficiently

**Connection timeouts:**
- Increase `checkout_timeout`
- Check network latency
- Verify database is responsive

## See Also

- [Configure Database Connection](database-connection.md)
- [Configure Multiple Environments](environments.md)
- [Enable SSL Connections](ssl.md)
