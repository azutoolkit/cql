# Explanation

Background on how CQL works and why it is designed the way it is. For step-by-step tasks, see the [How-to Guides](../how-to/README.md).

## Concepts

- [What is an ORM?](concepts/what-is-orm.md): what object-relational mapping does, what it buys you, and CQL's exits when it gets in the way

## Design Patterns

- [Active Record Pattern](design-patterns/active-record.md): the pattern CQL's models follow
- [Repository Pattern](design-patterns/repository.md): `CQL::Repository` and repositories written around a model

## Query DSL

- [Typed Query DSL: Before and After](dsl-before-after.md): what the typed DSL checks at compile time, side by side with the old forms
- [Safety Guardrails](safety-guardrails.md): parameter binding, identifier validation and compile-time checks

## Architecture

- [How CQL Keeps Queries Fast](performance-design.md): the stages of a query, what is off by default, and what is computed once
