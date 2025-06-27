# Contributing to Stark Insured

We're excited that you're interested in contributing to Stark Insured! This document outlines the process for contributing to our decentralized insurance protocol.

## 🚀 Getting Started

### Prerequisites

- [Cairo](https://book.cairo-lang.org/ch01-01-installation.html) >= 2.4.0
- [Scarb](https://docs.swmansion.com/scarb/download.html) >= 2.4.0
- [Starknet Foundry](https://foundry-rs.github.io/starknet-foundry/getting-started/installation.html)
- Git knowledge
- Understanding of StarkNet and Cairo

### Development Setup

1. **Fork the repository**
   \`\`\`bash
   git clone https://github.com/your-username/stark-insured-contracts.git
   cd stark-insured-contracts
   \`\`\`

2. **Install dependencies**
   \`\`\`bash
   scarb build
   \`\`\`

3. **Run tests**
   \`\`\`bash
   ./scripts/test.sh
   \`\`\`

4. **Set up environment**
   \`\`\`bash
   cp .env.example .env
   # Edit .env with your configuration
   \`\`\`

## 📋 Development Workflow

### Issue Assignment

1. **Find an issue** in the [Issues](https://github.com/stark-insured/contracts/issues) tab
2. **Comment on the issue** expressing your interest
3. **Wait for assignment** from a maintainer
4. **Submit PR within 24 hours** of assignment

### Branch Naming

Use descriptive branch names:
- `feat/policy-premium-calculation`
- `fix/claim-processing-bug`
- `docs/update-api-documentation`
- `test/add-risk-pool-tests`

### Commit Messages

Follow the conventional commit format:

\`\`\`
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
\`\`\`

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `test`: Adding or updating tests
- `refactor`: Code refactoring
- `style`: Code style changes
- `chore`: Maintenance tasks

**Examples:**
\`\`\`bash
feat(policy): implement premium calculation logic
fix(claims): resolve cooldown period validation
docs(readme): update deployment instructions
test(pools): add risk pool deposit tests
\`\`\`

### Code Style

1. **Format your code**
   \`\`\`bash
   scarb fmt
   \`\`\`

2. **Follow Cairo conventions**
   - Use snake_case for variables and functions
   - Use PascalCase for structs and enums
   - Use SCREAMING_SNAKE_CASE for constants

3. **Add comprehensive comments**
   ```cairo
   /// Calculates the premium amount based on coverage and risk factors
   /// # Arguments
   /// * `coverage_amount` - The total coverage amount in tokens
   /// * `duration` - Policy duration in seconds
   /// * `risk_score` - Risk assessment score (0-1000)
   /// # Returns
   /// * `u256` - Calculated premium amount
   fn calculate_premium(coverage_amount: u256, duration: u64, risk_score: u256) -> u256 {
       // Implementation
   }
   \`\`\`

## 🧪 Testing Guidelines

### Writing Tests

1. **Test file naming**: `test_<contract_name>.cairo`
2. **Test function naming**: `test_<functionality>()`
3. **Use descriptive assertions**:
   ```cairo
   assert(policy.is_active == true, 'Policy should be active');
   \`\`\`

### Test Categories

- **Unit Tests**: Test individual functions
- **Integration Tests**: Test contract interactions
- **Edge Cases**: Test boundary conditions
- **Security Tests**: Test attack vectors

### Running Tests

\`\`\`bash
# Run all tests
./scripts/test.sh

# Run specific test file
snforge test tests/test_policy_manager.cairo

# Run with coverage
snforge test --coverage
\`\`\`

## 📝 Pull Request Process

### Before Submitting

1. **Ensure tests pass**
   \`\`\`bash
   ./scripts/test.sh
   \`\`\`

2. **Format code**
   \`\`\`bash
   scarb fmt
   \`\`\`

3. **Build successfully**
   \`\`\`bash
   scarb build
   \`\`\`

4. **Update documentation** if needed

### PR Description Template

\`\`\`markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Tests pass locally
- [ ] Added new tests for functionality
- [ ] Updated existing tests

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No breaking changes (or documented)

## Related Issues
Closes #[issue_number]
\`\`\`

### Review Process

1. **Automated checks** must pass
2. **At least one maintainer** must approve
3. **All conversations** must be resolved
4. **No merge conflicts**

## 🛡️ Security Guidelines

### Security Best Practices

1. **Input Validation**
   ```cairo
   assert(amount > 0, 'Amount must be positive');
   assert(utils::is_valid_address(address), 'Invalid address');
   \`\`\`

2. **Reentrancy Protection**
   ```cairo
   self.reentrancy_guard.start();
   // External calls
   self.reentrancy_guard.end();
   \`\`\`

3. **Access Control**
   ```cairo
   self.ownable.assert_only_owner();
   \`\`\`

4. **Safe Math Operations**
   ```cairo
   let result = amount.checked_add(fee).expect('Math overflow');
   \`\`\`

### Security Review

- All PRs with security implications require additional review
- Consider attack vectors and edge cases
- Document security assumptions
- Use established security patterns

## 📚 Documentation

### Code Documentation

- Add docstrings to all public functions
- Explain complex logic with comments
- Update README.md for significant changes
- Add examples for new features

### Architecture Documentation

- Update `/docs/` for architectural changes
- Include diagrams for complex flows
- Document integration points
- Explain design decisions

## 🎯 Contribution Areas

### High Priority

- Security improvements
- Gas optimization
- Test coverage
- Documentation
- Bug fixes

### Feature Development

- Oracle integration
- Advanced risk scoring
- DAO governance features
- UI/UX improvements
- Integration tools

### Research Areas

- Novel insurance mechanisms
- Cross-chain compatibility
- MEV protection
- Scalability solutions

## 🤝 Community

### Communication Channels

- **Discord**: [Join our server](https://discord.gg/stark-insured)
- **Twitter**: [@stark_insured](https://twitter.com/stark_insured)
- **GitHub Discussions**: For design discussions

### Code of Conduct

- Be respectful and inclusive
- Provide constructive feedback
- Help newcomers learn
- Focus on the code, not the person
- Follow community guidelines

## 🎉 Recognition

Contributors are recognized in:
- README.md contributors section
- Release notes
- Community highlights
- Potential bounties and rewards

## ❓ Getting Help

- **Discord**: Real-time help and discussion
- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: Design and architecture discussions
- **Documentation**: Comprehensive guides and references

Thank you for contributing to Stark Insured! 🚀
