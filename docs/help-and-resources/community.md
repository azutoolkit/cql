# Community

_Connect with other developers, get help, and contribute to the CQL ecosystem_

***

## 👥 Join the Community

### 💬 Communication Channels

#### GitHub Discussions

* [**CQL Discussions**](https://github.com/azutoolkit/cql/discussions) - Main community hub
  * 💭 General discussions about CQL usage
  * 🤔 Questions and help requests
  * 💡 Feature requests and ideas
  * 📢 Announcements and updates

#### Crystal Language Community

* [**Crystal Forum**](https://forum.crystal-lang.org/) - Crystal language discussions
* [**Crystal Gitter**](https://gitter.im/crystal-lang/crystal) - Real-time chat
* [**Crystal Discord**](https://discord.gg/YS7YvQy) - Community Discord server
* [**Crystal Reddit**](https://www.reddit.com/r/crystal_programming/) - Reddit community

### 📚 Learning Resources

#### Official Documentation

* [**CQL Documentation**](../) - Complete CQL guide
* [**Crystal Documentation**](https://crystal-lang.org/docs/) - Crystal language docs
* [**Crystal API Docs**](https://crystal-lang.org/api/) - Crystal standard library

#### Community Resources

* **Example Applications** - Real-world CQL usage examples
* **Video Tutorials** - Community-created learning content
* **Blog Posts** - Developer experiences and tutorials
* **Case Studies** - Production usage stories

***

## 🆘 Getting Help

### 🔍 Before Asking for Help

1. **Search Existing Issues**: Check [GitHub Issues](https://github.com/azutoolkit/cql/issues)
2. **Review Documentation**: Explore our comprehensive docs
3. **Check Examples**: Look at example applications
4. **Search Community**: Browse discussions and forums

### ❓ How to Ask Good Questions

#### ✅ Good Question Format

````markdown
**Problem:** Brief description of what you're trying to achieve

**Current Code:**

```crystal
# Your current CQL code here
class User
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: UserDB, table: :users
  # ... model definition
end

# The code that's not working
users = User.where(active: true).all
```
````

**Expected Behavior:** What you expect to happen

**Actual Behavior:** What actually happens (include error messages)

**Environment:**

* Crystal version: X.X.X
* CQL version: X.X.X
* Database: PostgreSQL/MySQL/SQLite
* OS: macOS/Linux/Windows

**Additional Context:** Any other relevant information

````

#### ❌ Questions to Avoid
- "It doesn't work" (without details)
- "How do I do everything?" (too broad)
- Asking the same question multiple times
- Not providing code examples or error messages

### 🎯 Where to Ask Different Types of Questions

| Question Type | Best Place | Response Time |
|---------------|------------|---------------|
| **Bug Reports** | [GitHub Issues](https://github.com/azutoolkit/cql/issues) | 1-3 days |
| **Usage Questions** | [GitHub Discussions](https://github.com/azutoolkit/cql/discussions) | 1-2 days |
| **Feature Requests** | [GitHub Issues](https://github.com/azutoolkit/cql/issues) | 1-7 days |
| **Quick Help** | [Crystal Discord](https://discord.gg/YS7YvQy) | Minutes-Hours |
| **General Discussion** | [Crystal Forum](https://forum.crystal-lang.org/) | 1-2 days |

---

## 🤝 Contributing to CQL

### 🎯 Ways to Contribute

#### 1. Report Bugs
- **Found a bug?** Create a detailed issue with reproduction steps
- **Include examples** that demonstrate the problem
- **Test against latest version** to ensure it's still an issue

#### 2. Suggest Features
- **Have an idea?** Open a feature request issue
- **Explain the use case** and why it would be valuable
- **Consider implementation complexity** and backwards compatibility

#### 3. Improve Documentation
- **Fix typos** and clarify confusing sections
- **Add examples** for better understanding
- **Write guides** for common use cases
- **Translate documentation** to other languages

#### 4. Contribute Code
- **Fix bugs** with pull requests
- **Implement features** that have been approved
- **Improve performance** and add optimizations
- **Expand test coverage** for better reliability

#### 5. Share Knowledge
- **Write blog posts** about your CQL experiences
- **Create tutorials** for specific use cases
- **Give talks** at meetups and conferences
- **Answer questions** in community channels

### 🔧 Development Setup

#### Prerequisites
```bash
# Install Crystal
brew install crystal  # macOS
# or follow https://crystal-lang.org/install/ for other platforms

# Install dependencies
sudo apt-get install libsqlite3-dev    # Ubuntu/Debian
brew install sqlite                    # macOS
````

#### Clone and Setup

```bash
# Fork the repository on GitHub, then:
git clone https://github.com/YOUR_USERNAME/cql.git
cd cql

# Install dependencies
shards install

# Run tests to ensure everything works
crystal spec
```

#### Running Specific Tests

```bash
# Run all tests
crystal spec

# Run specific test file
crystal spec spec/operations/active_record/insertable_spec.cr

# Run tests with pattern
crystal spec --grep "validation"
```

### 📝 Contribution Guidelines

#### Code Style

* **Follow Crystal conventions** - Use standard Crystal formatting
* **Write clear code** - Prefer readability over cleverness
* **Add comments** for complex logic
* **Use meaningful names** for variables and methods

#### Testing Requirements

* **Write tests** for all new functionality
* **Ensure existing tests pass** before submitting
* **Test edge cases** and error conditions
* **Include integration tests** for complex features

#### Pull Request Process

1.  **Create a feature branch** from `master`

    ```bash
    git checkout -b feature/your-feature-name
    ```
2.  **Make your changes** with clear, focused commits

    ```bash
    git commit -m "Add user validation for email uniqueness"
    ```
3. **Update documentation** if needed
   * Update relevant docs in `/docs`
   * Add or update examples
   * Update API documentation
4.  **Run tests and ensure they pass**

    ```bash
    crystal spec
    ```
5. **Submit a pull request**
   * Use a clear, descriptive title
   * Explain what changes you made and why
   * Reference any related issues
   * Include testing information

#### Commit Message Format

```
Type: Brief description (50 chars max)

Longer explanation if needed (wrap at 72 chars)

- Bullet points for multiple changes
- Reference issues: Fixes #123, Closes #456

Co-authored-by: Name <email@example.com>
```

**Types:**

* `feat:` New feature
* `fix:` Bug fix
* `docs:` Documentation changes
* `test:` Adding or modifying tests
* `refactor:` Code refactoring
* `perf:` Performance improvements
* `style:` Code style changes

***

## 🏆 Recognition

### 📜 Hall of Fame

We recognize and celebrate community contributions:

#### Core Contributors

* **\[Maintainer Name]** - Project maintainer and architect
* **\[Contributor Name]** - Major feature contributions
* **\[Documentation Lead]** - Documentation improvements

#### Community Champions

* **Active Helpers** - Community members who consistently help others
* **Documentation Heroes** - Contributors who improve our docs
* **Bug Hunters** - Developers who find and report important issues

### 🎖️ Contribution Levels

#### Bronze Contributors (1-5 contributions)

* Name listed in CONTRIBUTORS.md
* Special contributor badge in GitHub
* Recognition in release notes

#### Silver Contributors (6-15 contributions)

* All Bronze benefits
* Featured in quarterly community newsletter
* Priority support for questions

#### Gold Contributors (16+ contributions)

* All Silver benefits
* Invited to monthly contributor calls
* Input on project roadmap decisions

***

## 📅 Community Events

### 🗓️ Regular Events

#### Monthly Community Calls

* **When:** First Wednesday of each month, 3 PM UTC
* **Where:** Video call (link announced in discussions)
* **What:** Project updates, Q\&A, community showcase

#### Quarterly Contributor Meetups

* **When:** Last Friday of each quarter
* **Where:** Virtual meetup
* **What:** Deep dive into upcoming features, architecture discussions

### 🎪 Special Events

#### Annual CQL Conference

* **Community presentations** on real-world usage
* **Workshops** for beginners and advanced users
* **Networking** with other Crystal developers

#### Hackathons

* **Build apps** using CQL
* **Create tools** that improve the CQL ecosystem
* **Win prizes** and recognition

***

## 📈 Project Roadmap

### 🎯 Current Priorities

1. **Performance Optimization** - Query execution improvements
2. **Advanced Relationships** - Polymorphic associations
3. **Migration Tools** - Better schema migration utilities
4. **Documentation** - Comprehensive guides and examples

### 🔮 Future Vision

* **Multi-database Support** - Enhanced cross-database capabilities
* **Advanced Query DSL** - More expressive query building
* **Real-time Features** - Live query subscriptions
* **Visual Tools** - GUI for schema management

### 🗳️ Community Input

* **Feature voting** on GitHub discussions
* **Roadmap surveys** quarterly
* **Contributor feedback** on priorities

***

## 📄 Code of Conduct

### 🤝 Our Commitment

We are committed to providing a welcoming, inclusive, and harassment-free experience for everyone, regardless of:

* Gender, gender identity, and expression
* Sexual orientation
* Disability
* Physical appearance
* Race and ethnicity
* Age
* Religion or lack thereof
* Technology choices

### ✅ Expected Behavior

* **Be respectful** of differing viewpoints and experiences
* **Accept constructive criticism** gracefully
* **Focus on what's best** for the community
* **Show empathy** towards other community members
* **Use welcoming and inclusive language**

### ❌ Unacceptable Behavior

* Harassment, discrimination, or hate speech
* Personal attacks or trolling
* Spam or off-topic content
* Sharing private information without permission
* Any conduct that would be inappropriate in a professional setting

### 🚨 Reporting Issues

If you experience or witness unacceptable behavior:

1. **Contact project maintainers** via email
2. **Report on GitHub** if comfortable doing so
3. **Reach out privately** to trusted community members

All reports will be handled confidentially and fairly.

***

## 📞 Contact Information

### 📧 Direct Contact

* **Project Maintainer:** \[Email]
* **Documentation Team:** \[Email]
* **Community Manager:** \[Email]

### 🔗 Quick Links

* [**GitHub Repository**](https://github.com/azutoolkit/cql)
* [**Issue Tracker**](https://github.com/azutoolkit/cql/issues)
* [**Discussions**](https://github.com/azutoolkit/cql/discussions)
* [**Contributing Guide**](../guides/contributing.md)

***

**Welcome to the CQL Community! 🎉**

We're excited to have you join us in building the future of Crystal database development. Whether you're here to learn, contribute, or just connect with other developers, we're here to help you succeed.

_Happy coding!_ 💎
