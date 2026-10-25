# Contributing

Thank you for your interest in contributing to CQL!

## Ways to Contribute

### Report Bugs

If you find a bug, please [open an issue](https://github.com/azutoolkit/cql/issues/new) with:

- A clear title and description
- Steps to reproduce the bug
- Expected vs actual behavior
- Your environment (CQL version, Crystal version, OS, database)

### Suggest Features

Feature requests are welcome! Open an issue describing:

- The problem you're trying to solve
- Your proposed solution
- Any alternatives you've considered

### Submit Pull Requests

1. **Fork the repository**

2. **Create a branch**
   ```shell
   git checkout -b feature/my-new-feature
   ```

3. **Make your changes**
   - Follow Crystal style guidelines
   - Add tests for new functionality
   - Update documentation if needed

4. **Run tests**
   ```shell
   crystal spec
   ```

5. **Format and lint your code**
   ```shell
   crystal tool format src spec     # apply formatting
   crystal tool format --check src spec  # what CI checks
   bin/ameba                        # lint (build it first with `shards build ameba`)
   ```

6. **Commit your changes**
   ```shell
   git commit -m "Add feature: description"
   ```

7. **Push and open a PR**
   ```shell
   git push origin feature/my-new-feature
   ```

## Code Guidelines

### Style

- Follow Crystal's standard style guide
- Use `crystal tool format` before committing
- Write clear, descriptive names for methods and variables
- Add comments for complex logic

### Testing

- Write tests for all new features
- A bug fix comes with a regression spec that fails without the fix
- Ensure existing tests pass
- Test edge cases and error conditions
- Live specs run on SQLite. Other dialects are verified by generated-SQL specs, for example `Expression::Generator.new(CQL::Adapter::Postgres)` with `query.to_sql(generator)`; PostgreSQL and Redis specs are marked pending when no server is available
- SQL assertions follow `spec/core/query_spec.cr`: `query.to_sql.should eq({sql, params})`

### Code Design

- Values are always bound as parameters; identifiers go through `CQL::Identifier` or `Dialect#quote_identifier`. Never interpolate user input into SQL
- Add a feature as a new AST node, a visitor method and a dialect hook rather than `if`/`case` branches on the adapter. In `Expression::Generator`, a node that appears inside statements writes its SQL with a private `write(node, io)` overload and gets its String `visit` from `visit_through_write`; a node without one falls back to its String `visit`

### Documentation

- Update documentation for public API changes
- Add code examples for new features
- Use clear, concise language
- Record behavior changes under `[Unreleased]` in `CHANGELOG.md`

## Pull Request Process

1. Update the README.md with details of changes if applicable
2. Update the documentation with any new features
3. Add a `CHANGELOG.md` entry under `[Unreleased]`
4. The PR will be merged once it has been reviewed and approved

## Development Setup

1. Clone the repository:
   ```shell
   git clone https://github.com/azutoolkit/cql.git
   cd cql
   ```

2. Install dependencies:
   ```shell
   shards install --ignore-crystal-version
   ```

3. Run tests:
   ```shell
   crystal spec                              # full suite
   crystal spec spec/core/query_spec.cr      # one file
   ```

   Without a MySQL client installed, one spec errors because `mysqldump` is missing
   (`spec/integration/dialects/mysql_dialect_spec.cr`). That is an environment issue, not a regression.

## Questions?

If you have questions about contributing, open a discussion on GitHub or ask in the issue tracker.

Thank you for contributing!
