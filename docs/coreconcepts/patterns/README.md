# Patterns

Software design patterns are general, reusable solutions to commonly occurring problems within a given context in software design. In the realm of Object-Relational Mapping (ORM) and database interaction, several established patterns help structure how applications access and manipulate data.

This section explores some of the key data access and ORM patterns that can be implemented or are relevant when working with Crystal Query Language (CQL). Understanding these patterns can help you design more maintainable, scalable, and understandable data access layers in your Crystal applications.

We will delve into the following patterns:

- **[Active Record](./active-record.md)**: An object that wraps a row in a database table or view, encapsulates database access, and adds domain logic on that data.
- **[Entity Framework (Conceptual Overview)](./entity-framework.md)**: While CQL is not a direct port of Microsoft's Entity Framework, this section will discuss some conceptual similarities or how related ideas (like a rich object context and LINQ-style querying) might apply or inspire usage with CQL.
- **[Repository](./repository.md)**: Mediates between the domain and data mapping layers using a collection-like interface for accessing domain objects.

Each pattern offers different trade-offs in terms of simplicity, flexibility, testability, and separation of concerns. Explore the specific guides to understand how they can be applied with CQL.
