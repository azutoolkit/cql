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

5. **Format your code**
   ```shell
   crystal tool format
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
- Ensure existing tests pass
- Test edge cases and error conditions

### Documentation

- Update documentation for public API changes
- Add code examples for new features
- Use clear, concise language

## Pull Request Process

1. Update the README.md with details of changes if applicable
2. Update the documentation with any new features
3. The PR will be merged once it has been reviewed and approved

## Development Setup

1. Clone the repository:
   ```shell
   git clone https://github.com/azutoolkit/cql.git
   cd cql
   ```

2. Install dependencies:
   ```shell
   shards install
   ```

3. Run tests:
   ```shell
   crystal spec
   ```

## Questions?

If you have questions about contributing, open a discussion on GitHub or ask in the issue tracker.

Thank you for contributing!
