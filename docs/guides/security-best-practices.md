# Security Best Practices for CQL

> **Protect your application** - Essential security guidelines for building secure database applications with CQL

## Overview

This guide provides practical security advice for CQL developers. Following these practices will help protect your application from SQL injection and other database security vulnerabilities.

---

## Quick Security Checklist

Before deploying to production:

- [ ] All user inputs use parameterized queries
- [ ] No string interpolation in SQL statements
- [ ] Column/table names are whitelisted
- [ ] Database user has minimal required permissions
- [ ] TLS/SSL enabled for database connections
- [ ] Query logging enabled in staging
- [ ] Error messages don't expose sensitive data
- [ ] Input validation on all user-provided data

---

## SQL Injection Prevention

### The Golden Rule

**Never use string interpolation with user input in SQL.**

### ✅ Safe Patterns

#### 1. Hash-Based Queries (Recommended)

```crystal
# User input is automatically parameterized
email = params[:email]  # User-provided input
user = User.where(email: email).first

# Multiple conditions
User.where(
  email: params[:email],
  active: true
).all
```

#### 2. Placeholder Queries

```crystal
# Use ? placeholders for values
User.query
  .where("age > ? AND age < ?", min_age, max_age)
  .all(User)

# Complex conditions
User.query
  .where("created_at BETWEEN ? AND ?", start_date, end_date)
  .where(active: true)
  .all(User)
```

#### 3. Active Record Methods

```crystal
# All Active Record methods are safe
User.find(params[:id])
User.find_by(email: user_email)
User.create(name: user_name, email: user_email)

Post.where(published: true).all
Post.where(author_id: current_user.id).all
```

#### 4. Explicit NULL Handling

```crystal
# Clear intent, safe implementation
User.query.where_null(:deleted_at).all(User)
User.query.where_not_null(:email_verified_at).all(User)
```

### ❌ Dangerous Patterns

#### Never Do This

```crystal
# ❌ String interpolation - DANGEROUS
email = params[:email]
User.query.where("email = '#{email}'").all(User)

# ❌ Direct SQL with user input - DANGEROUS
schema.exec("DELETE FROM users WHERE id = #{params[:id]}")

# ❌ Unvalidated identifiers - DANGEROUS
column = params[:sort_by]
User.query.order(column).all(User)
```

---

## Input Validation

### Validate All User Input

Even with parameterized queries, validate input:

```crystal
# Validate ID is actually an integer
def find_user(id_param : String) : User?
  id = id_param.to_i64?
  return nil unless id && id > 0
  User.find(id)
end

# Validate email format
EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

def find_by_email(email : String) : User?
  return nil unless email =~ EMAIL_REGEX
  User.find_by(email: email)
end

# Validate enum values
VALID_STATUSES = ["pending", "approved", "rejected"]

def filter_by_status(status : String)
  return [] unless VALID_STATUSES.includes?(status)
  Order.where(status: status).all
end
```

### Use Crystal's Type System

```crystal
# Type system prevents type confusion
def create_user(
  email : String,
  age : Int32,
  active : Bool
)
  # age MUST be Int32, can't be SQL string
  # active MUST be Bool
  User.create(email: email, age: age, active: active)
end

# Enum types for limited values
enum UserRole
  Admin
  User
  Guest
end

struct User
  property role : UserRole
end
```

---

## Column and Table Name Safety

### Always Whitelist Identifiers

```crystal
# ❌ DANGEROUS - User controls column name
def sort_users(sort_by : String)
  User.query.order(sort_by).all(User)
end

# ✅ SAFE - Whitelist approach
ALLOWED_SORT_COLUMNS = {
  "name"    => :name,
  "email"   => :email,
  "created" => :created_at,
}

def sort_users(sort_by : String, direction : String = "asc")
  column = ALLOWED_SORT_COLUMNS[sort_by]?
  return [] unless column

  dir = direction == "desc" ? :desc : :asc
  User.query.order(column => dir).all(User)
end
```

### Use Symbols for Known Identifiers

```crystal
# ✅ SAFE - Symbols are compile-time constants
User.query.from(:users).select(:id, :email, :name).all

# ❌ RISKY - Strings could be manipulated
table_name = params[:table]
schema.query.from(table_name).all  # Don't do this!
```

---

## LIKE Query Safety

### Escape Wildcards in User Input

```crystal
# User search term
search = params[:q]  # Could be: "admin%' OR '1'='1"

# ⚠️ PARTIALLY SAFE - Parameterized but wildcards aren't escaped
User.query.where("name LIKE ?", "%#{search}%").all(User)

# ✅ FULLY SAFE - Escape wildcards
def escape_like(str : String) : String
  str.gsub(/[%_\\]/) { |m| "\\#{m}" }
end

search_safe = escape_like(params[:q])
User.query.where("name LIKE ?", "%#{search_safe}%").all(User)

# Alternative: Use prefix/suffix matching
User.query.where("name LIKE ?", "#{search}%").all(User)  # Prefix only
```

---

## Error Handling

### Don't Leak Information

```crystal
# ❌ BAD - Exposes database structure
begin
  User.find!(params[:id])
rescue ex
  render json: {error: ex.message}  # Might expose column names, constraints
end

# ✅ GOOD - Generic error messages
begin
  User.find!(params[:id])
rescue CQL::RecordNotFound
  render json: {error: "User not found"}, status: 404
rescue ex
  Log.error { "Database error: #{ex.message}" }  # Log internally
  render json: {error: "An error occurred"}, status: 500
end
```

### Sanitize Error Messages

```crystal
def safe_error_message(ex : Exception) : String
  case ex
  when CQL::RecordNotFound
    "Record not found"
  when CQL::RecordInvalid
    "Invalid data provided"
  when DB::Error
    "Database error occurred"  # Don't expose details
  else
    "An error occurred"
  end
end
```

---

## Database Configuration

### Minimal Permissions

```sql
-- Application database user (PostgreSQL example)
CREATE USER app_user WITH PASSWORD 'secure_password';

-- Only grant necessary permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user;

-- NO DROP, CREATE, ALTER permissions
-- NO superuser privileges
```

### Read-Only User for Reports

```sql
-- Separate user for reporting queries
CREATE USER report_user WITH PASSWORD 'secure_password';
GRANT SELECT ON ALL TABLES IN SCHEMA public TO report_user;
```

### Connection Security

```crystal
# Enable TLS for database connections
CQL.configure do |config|
  config.db = "postgres://user:pass@localhost/db?sslmode=require"
end

# PostgreSQL SSL modes:
# - disable: No SSL
# - allow: Try SSL, fallback to non-SSL
# - prefer: Try SSL, fallback to non-SSL (default)
# - require: Require SSL, verify server identity
# - verify-ca: Require SSL, verify server certificate
# - verify-full: Require SSL, verify server certificate and hostname
```

---

## Query Monitoring

### Enable Query Logging

```crystal
# Development environment
CQL.configure do |config|
  config.logger.level = Logger::DEBUG
end

# Review logs for:
# - Unusually long execution times
# - SQL syntax errors from injection attempts
# - Excessive query counts
# - Suspicious patterns
```

### Detect Suspicious Patterns

```crystal
# Add query monitoring
module QueryMonitor
  SUSPICIOUS_PATTERNS = [
    /union\s+select/i,
    /;\s*drop\s+table/i,
    /;\s*delete\s+from/i,
    /sleep\(/i,
    /benchmark\(/i,
    /waitfor\s+delay/i,
  ]

  def self.check(sql : String)
    SUSPICIOUS_PATTERNS.each do |pattern|
      if sql =~ pattern
        Log.warn { "Suspicious SQL detected: #{sql[0..100]}" }
        # Consider: alert security team, block request
      end
    end
  end
end
```

---

## Testing for Security

### Include Security Tests

```crystal
describe "SQL Injection Prevention" do
  it "escapes single quotes in WHERE clauses" do
    malicious = "admin' OR '1'='1"
    users = User.where(name: malicious).all

    # Should return empty (no user with that name)
    # Should NOT return all users
    users.should be_empty
  end

  it "prevents UNION injection" do
    malicious = "1 UNION SELECT password FROM users"
    user = User.find_by(id: malicious)

    # Should return nil (invalid ID type)
    user.should be_nil
  end

  it "validates column names" do
    malicious = "id; DROP TABLE users--"

    expect_raises(Exception) do
      User.query.order(malicious).all(User)
    end
  end
end
```

---

## Production Checklist

### Before Going Live

#### Application Level

- [ ] All queries use parameterized syntax
- [ ] Input validation on all user inputs
- [ ] Column/table names whitelisted
- [ ] Error messages sanitized
- [ ] Query logging enabled
- [ ] Security tests passing

#### Database Level

- [ ] Application user has minimal permissions
- [ ] Separate read-only user for reports
- [ ] TLS/SSL enabled and enforced
- [ ] Strong passwords (preferably cert-based auth)
- [ ] Connection limits configured
- [ ] Audit logging enabled

#### Infrastructure Level

- [ ] Database not exposed to public internet
- [ ] Firewall rules restrict access
- [ ] Regular security patches applied
- [ ] Backups encrypted
- [ ] Monitoring and alerting configured

---

## Common Attack Vectors

### 1. Classic SQL Injection

```crystal
# Attack attempt
email = "admin@example.com' OR '1'='1' --"

# ❌ Vulnerable code
schema.exec("SELECT * FROM users WHERE email = '#{email}'")
# SQL: SELECT * FROM users WHERE email = 'admin@example.com' OR '1'='1' --'
# Result: Returns ALL users

# ✅ Safe code
User.where(email: email).all
# Parameters: ["admin@example.com' OR '1'='1' --"]
# Result: Returns users with that exact (weird) email, probably none
```

### 2. Second-Order Injection

```crystal
# First request: Store malicious data
user = User.create(name: "admin'; DROP TABLE logs--")

# Second request: Use data unsafely
# ❌ DANGEROUS
schema.exec("INSERT INTO logs (user) VALUES ('#{user.name}')")

# ✅ SAFE
schema.query.from(:logs).values(user: user.name).insert
```

### 3. Blind Injection

```crystal
# Attack: Time-based detection
id = "1 AND (SELECT SLEEP(5)) --"

# ❌ Vulnerable: Takes 5 seconds if vulnerable
schema.exec("SELECT * FROM users WHERE id = #{id}")

# ✅ Safe: Parameter type mismatch, returns nil
User.find(id)  # id is String, expected Int64
```

---

## Additional Resources

- [OWASP SQL Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)
- [CQL Security Audit](../../SECURITY_AUDIT.md)
- [CQL Testing Guide](./testing-coverage.md)
- [Crystal Security Guide](https://crystal-lang.org/reference/guides/security.html)

---

## Need Help?

If you discover a security vulnerability:

1. **DO NOT** open a public issue
2. Email security@[project-domain] with details
3. Include proof-of-concept if possible
4. Allow time for fix before disclosure

---

**Last Updated:** October 11, 2025
**Version:** 1.0
