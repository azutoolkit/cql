# CQL Blog Application Demo

This is an organized, modular version of the CQL blog application demo that showcases all the key features of the CQL ORM framework using a migration-based database schema approach.

## Structure

The demo has been organized into logical components for better maintainability and understanding:

### Core Components

- **`blog_demo.cr`** - Main demo runner that orchestrates all components
- **Configuration** - Database configuration and setup within the main demo
- **Migrations** - Migration runner and loader
- **`seeders.cr`** - Data seeding logic to populate the database

### Models (`models/`)

Individual model files for each entity:

- **`user.cr`** - User model with relationships and methods
- **`category.cr`** - Category model for organizing posts
- **`post.cr`** - Post model with content and metadata
- **`comment.cr`** - Comment model for user feedback

### Migrations (`migrations/`)

Individual migration files for each table:

- **`001_create_users.cr`** - Users table creation
- **`002_create_categories.cr`** - Categories table creation
- **`003_create_posts.cr`** - Posts table creation
- **`004_create_comments.cr`** - Comments table creation

### Demo Modules (`demos/`)

Focused demo modules showcasing specific features:

- **`crud_operations.cr`** - Create, Read, Update, Delete operations
- **`complex_queries.cr`** - Advanced queries, joins, and aggregations
- **`relationships.cr`** - Model relationship navigation
- **`performance_features.cr`** - Performance optimization features
- **`statistics_and_reporting.cr`** - Reporting and performance monitoring

## Running the Demo

To run the complete demo:

```bash
crystal examples/blog/blog_demo.cr
```

The demo will:

1. Configure the database connection
2. Run all migrations to set up the schema
3. Seed the database with sample data
4. Execute all demo modules showcasing CQL features
5. Generate a comprehensive performance report

## Features Demonstrated

### Core CQL Features

- ✅ Configuration management
- ✅ Schema definition with relationships
- ✅ Database migrations
- ✅ Active Record models
- ✅ CRUD operations
- ✅ Complex queries and joins
- ✅ Aggregations and statistics
- ✅ Relationship navigation
- ✅ Performance optimizations
- ✅ Raw SQL capabilities
- ✅ Performance monitoring and reporting

### Performance Monitoring

- ✅ Real-time query performance tracking
- ✅ N+1 query detection
- ✅ Slow query identification
- ✅ Beautiful developer-friendly reports
- ✅ Performance recommendations
- ✅ Query pattern analysis

## Database Schema

The demo creates a blog application with the following entities:

- **Users** - Blog authors and commenters
- **Categories** - Post categorization
- **Posts** - Blog content with metadata
- **Comments** - User feedback on posts

All relationships are properly defined with foreign keys and indexes for optimal performance.

## Demo Output

When you run the demo, you'll see:

1. **Configuration** - Database setup and connection
2. **Migrations** - Schema creation with version tracking
3. **Seeding** - Sample data creation
4. **CRUD Operations** - Basic database operations
5. **Complex Queries** - Advanced query patterns
6. **Relationships** - Model association navigation
7. **Performance Features** - Batch processing and optimizations
8. **Statistics** - Data analysis and reporting
9. **Performance Report** - Comprehensive monitoring results

## Benefits of This Organization

1. **Modularity** - Each component has a single responsibility
2. **Maintainability** - Easy to update individual features
3. **Reusability** - Components can be used independently
4. **Clarity** - Clean separation of concerns
5. **Testability** - Individual modules can be tested in isolation
6. **Migration-based Schema** - Individual migration files for better version control and team collaboration

## Recent Fixes

The demo has been updated to resolve several issues:

- ✅ Fixed SQL generation to properly handle `SELECT *` when no columns are specified
- ✅ Resolved relationship loading issues with proper column selection
- ✅ Fixed foreign key relationships in model definitions
- ✅ Improved error handling and debugging capabilities

This organized structure demonstrates CQL as a production-ready ORM suitable for real-world applications with comprehensive performance monitoring and debugging capabilities.
