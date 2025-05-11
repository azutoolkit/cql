# Relationships in CQL Active Record

This section provides comprehensive guides for defining and working with associations between models in CQL Active Record. Relationships are a core part of modeling real-world data and enable you to express connections such as ownership, membership, and linkage between records.

## What You'll Find

- **Overview of Association Types**: Learn the differences between one-to-one, one-to-many, and many-to-many relationships.
- **Step-by-Step Guides**: Each sub-guide covers how to set up, use, and query each type of association in CQL, with practical code examples.
- **Best Practices**: Tips for managing associations, avoiding common pitfalls, and writing maintainable code.

## Relationship Guides

- [Belongs To](./belongsto.md): How to set up and use `belongs_to` associations (e.g., a comment belongs to a post).
- [Has One](./hasone.md): How to define and work with `has_one` relationships (e.g., a user has one profile).
- [Has Many](./hasmany.md): How to manage `has_many` associations (e.g., a post has many comments).
- [Many To Many](./manytomany.md): How to implement many-to-many relationships using join tables (e.g., posts and tags).

Each guide includes:

- Schema and model setup
- Creating and querying associations
- Modifying and deleting related records
- Eager loading and performance tips

---

Use these guides to master associations in your CQL-powered Crystal applications!
