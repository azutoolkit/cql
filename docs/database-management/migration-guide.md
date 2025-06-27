# Migration Guide

_Step-by-step instructions for migrating from other ORMs to CQL_

***

## 📋 Overview

This guide helps you migrate existing applications from popular ORMs to CQL. We'll cover:

* **ActiveRecord (Ruby)** → CQL
* **Eloquent (PHP)** → CQL
* **Sequelize (JavaScript)** → CQL
* **TypeORM (TypeScript)** → CQL

***

## 🎯 Migration Strategy

### 1. Assessment Phase

* **Analyze Current Schema**: Document existing tables, relationships, and constraints
* **Identify Dependencies**: Find external integrations and database-specific features
* **Plan Migration**: Choose incremental vs. full migration approach

### 2. Preparation Phase

* **Set up Crystal Environment**: Install Crystal and CQL
* **Create New Project**: Initialize CQL project structure
* **Database Setup**: Configure database connections

### 3. Migration Phase

* **Schema Migration**: Recreate tables and relationships
* **Data Migration**: Transfer existing data
* **Business Logic**: Port model validations and methods
* **Testing**: Verify functionality and performance

***

## 🔴 From ActiveRecord (Ruby)

### Setting Up the Environment

```bash
# Install Crystal (macOS)
brew install crystal

# Create new Crystal project
crystal init app my_app
cd my_app

# Add CQL dependency to shard.yml
dependencies:
  cql:
    github: azutoolkit/cql
    branch: master
```

### Model Migration

#### Before (ActiveRecord)

```ruby
class User < ApplicationRecord
  validates :name, presence: true, length: { minimum: 2 }
  validates :email, presence: true, uniqueness: true
  validates :age, numericality: { greater_than: 0 }

  has_many :posts, dependent: :destroy
  has_one :profile, dependent: :destroy

  scope :active, -> { where(active: true) }
  scope :adults, -> { where('age >= ?', 18) }

  before_save :normalize_email
  after_create :send_welcome_email

  private

  def normalize_email
    self.email = email.downcase.strip
  end

  def send_welcome_email
    UserMailer.welcome(self).deliver_now
  end
end
```

#### After (CQL)

```crystal
require "cql"

class User
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: UserDB, table: :users

  property id : Int64 = 0
  property name : String
  property email : String
  property age : Int32
  property active : Bool = true
  property created_at : Time = Time.utc
  property updated_at : Time = Time.utc

  # Validations
  validate :name, required: true, size: 2..50
  validate :email, required: true, unique: true
  validate :age, gt: 0

  # Relationships
  has_many :posts, Post, foreign_key: :user_id
  has_one :profile, Profile, foreign_key: :user_id

  # Scopes
  scope :active, -> { where(active: true) }
  scope :adults, -> { where { age >= 18 } }

  # Callbacks
  before_save :normalize_email
  after_create :send_welcome_email

  private def normalize_email
    self.email = email.downcase.strip
  end

  private def send_welcome_email
    # UserMailer.welcome(self).deliver
    puts "Welcome email sent to #{email}"
  end
end
```

### Schema Migration

#### Before (ActiveRecord Migration)

```ruby
class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.integer :age, null: false
      t.boolean :active, default: true
      t.timestamps
    end

    add_index :users, :email, unique: true
  end
end
```

#### After (CQL Schema)

```crystal
require "cql"

# Database configuration
UserDB = CQL::Database.new("sqlite3", "./user_db.db")

# Schema definition
class UserSchema < CQL::Schema(UserDB)
  table :users do |t|
    t.integer :id, primary: true, auto_increment: true
    t.string :name, null: false
    t.string :email, null: false, index: {unique: true}
    t.integer :age, null: false
    t.boolean :active, default: true
    t.timestamp :created_at, null: false
    t.timestamp :updated_at, null: false
  end
end

# Apply schema
UserSchema.apply!
```

### Query Migration

#### Before (ActiveRecord)

```ruby
# Basic queries
users = User.where(active: true).order(:name).limit(10)
user = User.find_by(email: "user@example.com")
count = User.where(age: 18..65).count

# Complex queries
adult_users = User.joins(:posts)
                 .where(active: true)
                 .where('posts.published = ?', true)
                 .group('users.id')
                 .having('COUNT(posts.id) > ?', 5)

# Eager loading
users_with_posts = User.joins(:posts, :profile)
                      .where(active: true)
```

#### After (CQL)

```crystal
# Basic queries
users = User.where(active: true).order(name: :asc).limit(10).all
user = User.find_by(email: "user@example.com")
count = User.where { (age >= 18) & (age <= 65) }.count

# Complex queries (simplified syntax)
adult_users = User.join(:posts)
                 .where(active: true)
                 .where { posts.published.eq(true) }
                 .group(:id)
                 .having { count(posts.id) > 5 }
                 .all

# Efficient loading
users_with_posts = User.join(:posts, :profile)
                      .where(active: true)
                      .all
```

***

## 🟡 From Eloquent (PHP)

### Model Migration

#### Before (Eloquent)

```php
<?php

class User extends Model
{
    protected $fillable = ['name', 'email', 'age'];
    protected $casts = [
        'active' => 'boolean',
        'email_verified_at' => 'datetime',
    ];

    public function posts()
    {
        return $this->hasMany(Post::class);
    }

    public function profile()
    {
        return $this->hasOne(Profile::class);
    }

    public function scopeActive($query)
    {
        return $query->where('active', true);
    }

    public function scopeAdults($query)
    {
        return $query->where('age', '>=', 18);
    }

    protected static function boot()
    {
        parent::boot();

        static::saving(function ($user) {
            $user->email = strtolower(trim($user->email));
        });

        static::created(function ($user) {
            // Send welcome email
            Mail::to($user)->send(new WelcomeEmail());
        });
    }
}
```

#### After (CQL)

```crystal
class User
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: UserDB, table: :users

  property id : Int64 = 0
  property name : String
  property email : String
  property age : Int32
  property active : Bool = true
  property email_verified_at : Time?
  property created_at : Time = Time.utc
  property updated_at : Time = Time.utc

  # Relationships
  has_many :posts, Post, foreign_key: :user_id
  has_one :profile, Profile, foreign_key: :user_id

  # Scopes
  scope :active, -> { where(active: true) }
  scope :adults, -> { where { age >= 18 } }

  # Callbacks (equivalent to Eloquent events)
  before_save :normalize_email
  after_create :send_welcome_email

  private def normalize_email
    self.email = email.downcase.strip
  end

  private def send_welcome_email
    # Send welcome email logic here
    puts "Welcome email sent to #{email}"
  end
end
```

### Query Migration

#### Before (Eloquent)

```php
// Basic queries
$users = User::where('active', true)
             ->orderBy('name')
             ->limit(10)
             ->get();

$user = User::where('email', 'user@example.com')->first();

// Complex queries
$activeUsers = User::with(['posts', 'profile'])
                  ->where('active', true)
                  ->whereHas('posts', function ($query) {
                      $query->where('published', true);
                  })
                  ->get();

// Scopes
$adults = User::active()->adults()->get();
```

#### After (CQL)

```crystal
# Basic queries
users = User.where(active: true)
           .order(name: :asc)
           .limit(10)
           .all

user = User.find_by(email: "user@example.com")

# Complex queries
active_users = User.join(:posts, :profile)
                  .where(active: true)
                  .where { posts.published.eq(true) }
                  .all

# Scopes
adults = User.active.adults.all
```

***

## 🔵 From Sequelize (JavaScript)

### Model Migration

#### Before (Sequelize)

```javascript
const { DataTypes } = require("sequelize");

const User = sequelize.define(
  "User",
  {
    name: {
      type: DataTypes.STRING,
      allowNull: false,
      validate: {
        len: [2, 255],
      },
    },
    email: {
      type: DataTypes.STRING,
      allowNull: false,
      unique: true,
      validate: {
        isEmail: true,
      },
    },
    age: {
      type: DataTypes.INTEGER,
      allowNull: false,
      validate: {
        min: 0,
      },
    },
    active: {
      type: DataTypes.BOOLEAN,
      defaultValue: true,
    },
  },
  {
    hooks: {
      beforeSave: (user) => {
        user.email = user.email.toLowerCase().trim();
      },
      afterCreate: (user) => {
        // Send welcome email
        console.log(`Welcome email sent to ${user.email}`);
      },
    },
    scopes: {
      active: {
        where: { active: true },
      },
      adults: {
        where: { age: { [Op.gte]: 18 } },
      },
    },
  }
);

// Associations
User.hasMany(Post, { foreignKey: "userId" });
User.hasOne(Profile, { foreignKey: "userId" });
```

#### After (CQL)

```crystal
class User
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: UserDB, table: :users

  property id : Int64 = 0
  property name : String
  property email : String
  property age : Int32
  property active : Bool = true
  property created_at : Time = Time.utc
  property updated_at : Time = Time.utc

  # Validations
  validate :name, size: 2..255
  validate :email, required: true, unique: true, match: EMAIL_REGEX
  validate :age, gte: 0

  # Relationships
  has_many :posts, Post, foreign_key: :user_id
  has_one :profile, Profile, foreign_key: :user_id

  # Scopes
  scope :active, -> { where(active: true) }
  scope :adults, -> { where { age >= 18 } }

  # Hooks (callbacks)
  before_save :normalize_email
  after_create :send_welcome_email

  private def normalize_email
    self.email = email.downcase.strip
  end

  private def send_welcome_email
    puts "Welcome email sent to #{email}"
  end
end
```

***

## 🟢 From TypeORM (TypeScript)

### Model Migration

#### Before (TypeORM)

```typescript
import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  OneToMany,
  OneToOne,
} from "typeorm";

@Entity()
export class User {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ length: 255 })
  name: string;

  @Column({ unique: true })
  email: string;

  @Column()
  age: number;

  @Column({ default: true })
  active: boolean;

  @Column()
  createdAt: Date;

  @Column()
  updatedAt: Date;

  @OneToMany(() => Post, (post) => post.user)
  posts: Post[];

  @OneToOne(() => Profile, (profile) => profile.user)
  profile: Profile;

  @BeforeInsert()
  @BeforeUpdate()
  normalizeEmail() {
    this.email = this.email.toLowerCase().trim();
  }

  @AfterInsert()
  sendWelcomeEmail() {
    console.log(`Welcome email sent to ${this.email}`);
  }
}
```

#### After (CQL)

```crystal
class User
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: UserDB, table: :users

  property id : Int64 = 0
  property name : String
  property email : String
  property age : Int32
  property active : Bool = true
  property created_at : Time = Time.utc
  property updated_at : Time = Time.utc

  # Relationships
  has_many :posts, Post, foreign_key: :user_id
  has_one :profile, Profile, foreign_key: :user_id

  # Callbacks
  before_save :normalize_email
  after_create :send_welcome_email

  private def normalize_email
    self.email = email.downcase.strip
  end

  private def send_welcome_email
    puts "Welcome email sent to #{email}"
  end
end
```

***

## 📊 Data Migration

### Export Data from Source

#### MySQL/PostgreSQL

```sql
-- Export to CSV
COPY users TO '/tmp/users.csv' DELIMITER ',' CSV HEADER;
COPY posts TO '/tmp/posts.csv' DELIMITER ',' CSV HEADER;
```

#### SQLite

```bash
# Export to CSV
sqlite3 -header -csv database.db "SELECT * FROM users;" > users.csv
sqlite3 -header -csv database.db "SELECT * FROM posts;" > posts.csv
```

### Import Data to CQL

```crystal
require "csv"

# Import users
CSV.each_row(File.open("users.csv")) do |row|
  next if row[0] == "id"  # Skip header

  User.create!(
    id: row[0].to_i64,
    name: row[1],
    email: row[2],
    age: row[3].to_i32,
    active: row[4] == "true",
    created_at: Time.parse(row[5], "%Y-%m-%d %H:%M:%S"),
    updated_at: Time.parse(row[6], "%Y-%m-%d %H:%M:%S")
  )
end

puts "Imported #{User.count} users"
```

***

## 🧪 Testing Migration

### Create Test Suite

```crystal
require "spec"
require "./src/models/user"

describe User do
  before_each do
    UserDB.users.create!
  end

  after_each do
    UserDB.users.drop!
  end

  describe "validations" do
    it "validates presence of name" do
      user = User.new(email: "test@example.com", age: 25)
      user.valid?.should be_false
      user.errors.messages[:name].should contain("can't be blank")
    end

    it "validates email format" do
      user = User.new(name: "Test", email: "invalid", age: 25)
      user.valid?.should be_false
    end
  end

  describe "scopes" do
    it "returns active users" do
      active_user = User.create!(name: "Active", email: "active@example.com", age: 25, active: true)
      inactive_user = User.create!(name: "Inactive", email: "inactive@example.com", age: 25, active: false)

      active_users = User.active.all
      active_users.size.should eq(1)
      active_users.first.id.should eq(active_user.id)
    end
  end

  describe "callbacks" do
    it "normalizes email before save" do
      user = User.create!(
        name: "Test",
        email: "  TEST@EXAMPLE.COM  ",
        age: 25
      )

      user.email.should eq("test@example.com")
    end
  end
end
```

### Performance Testing

```crystal
require "benchmark"

# Test query performance
puts "Testing query performance..."

time = Benchmark.measure do
  1000.times do
    User.where(active: true).limit(10).all
  end
end

puts "1000 queries took: #{time.total}s"
puts "Average per query: #{time.total / 1000}ms"

# Memory usage test
before_memory = GC.stats.heap_size
users = User.limit(10000).all
after_memory = GC.stats.heap_size

puts "Memory used for 10k records: #{after_memory - before_memory} bytes"
```

***

## 🎯 Best Practices

### 1. Incremental Migration

* **Start Small**: Migrate one model at a time
* **Dual Write**: Write to both old and new systems during transition
* **Gradual Cutover**: Switch reads gradually after verifying data integrity

### 2. Type Safety

* **Use Proper Types**: Leverage Crystal's type system
* **Handle Nils**: Use union types (String | Nil) for optional fields
* **Validate Conversions**: Ensure data type compatibility

### 3. Performance Optimization

* **Index Migration**: Recreate important indexes first
* **Batch Operations**: Use transactions for large data sets
* **Monitor Memory**: Crystal uses less memory, but monitor during migration

### 4. Error Handling

```crystal
# Robust migration with error handling
users_migrated = 0
errors = [] of String

CSV.each_row(File.open("users.csv")) do |row|
  begin
    User.create!(
      name: row[1],
      email: row[2],
      age: row[3].to_i32
    )
    users_migrated += 1
  rescue ex : Exception
    errors << "Row #{row[0]}: #{ex.message}"
  end
end

puts "Successfully migrated: #{users_migrated}"
puts "Errors: #{errors.size}"
errors.each { |error| puts error }
```

***

## 🔧 Common Issues and Solutions

### Issue 1: Crystal Type System

**Problem**: Dynamic types from source ORM don't match Crystal's static types

**Solution**:

```crystal
# Use union types for optional fields
property email : String?
property age : Int32?

# Handle type conversions explicitly
def age=(value)
  @age = value.is_a?(String) ? value.to_i32? : value
end
```

### Issue 2: Missing Callbacks

**Problem**: Some ORM-specific callbacks don't have direct equivalents

**Solution**:

```crystal
# Create custom callback methods
after_save :custom_logic

private def custom_logic
  # Your custom business logic here
end
```

### Issue 3: Query Syntax Differences

**Problem**: Complex query syntax differs between ORMs

**Solution**:

```crystal
# Break complex queries into simpler parts
active_users = User.where(active: true)
adult_users = active_users.where { age >= 18 }
recent_users = adult_users.where { created_at > 1.month.ago }
```

***

## ✅ Migration Checklist

### Pre-Migration

* [ ] Crystal environment set up
* [ ] CQL dependency added
* [ ] Database connection configured
* [ ] Backup of existing data created

### Schema Migration

* [ ] Tables recreated with correct types
* [ ] Indexes migrated
* [ ] Foreign key constraints added
* [ ] Default values configured

### Model Migration

* [ ] Properties defined with correct types
* [ ] Validations ported
* [ ] Relationships configured
* [ ] Callbacks implemented
* [ ] Scopes recreated

### Data Migration

* [ ] Data exported from source
* [ ] Data imported to CQL
* [ ] Data integrity verified
* [ ] Counts match between systems

### Testing

* [ ] Unit tests created
* [ ] Integration tests passing
* [ ] Performance benchmarks run
* [ ] Memory usage verified

### Deployment

* [ ] Application tested in staging
* [ ] Performance monitoring set up
* [ ] Rollback plan prepared
* [ ] Production deployment completed

***

## 🎓 Next Steps

After successful migration:

1. **Optimize Performance**: Use CQL's [performance guide](broken-reference)
2. **Add Advanced Features**: Explore [advanced querying](../active-record-with-cql/complex-queries.md)
3. **Set Up Monitoring**: Implement logging and metrics
4. **Train Team**: Share Crystal and CQL knowledge with your team

***

**Need Help?**

* 📚 [**Documentation**](../) - Complete CQL documentation
* 🆘 [**Troubleshooting**](../help-and-resources/troubleshooting.md) - Common problems and solutions
* 💬 [**Community**](../help-and-resources/community.md) - Get help from other developers
* 🐛 [**Issues**](https://github.com/azutoolkit/cql/issues) - Report bugs or request features
