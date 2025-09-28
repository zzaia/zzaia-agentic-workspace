## C#/.NET Language Standards

### Language Features

- Use primary constructors
- Prefer `DateTimeOffset.UtcNow`
- Use `string.IsNullOrWhiteSpace()`
- Use explicit types
- Avoid unnecessary arguments
- Avoid unnecessary nuget package references
- Never use `var` variable type

### Code Quality Rules

- Self-documenting code
- Avoid blank lines inside methods
- Clear naming conventions with pascal case
- Maximum of three words combined in names ex: `CreateBankAccountAsync`, `BankReferenceCode`
- Use `Async` in names when returning tasks
- No inline comments
- No inline spaces
- Fix build warnings

### Testing Standards

- Fluent assertion syntax
- Comprehensive test coverage
- Meaningful test output
- Do not unit test controllers

### Documentation Requirements

- XML documentation for public members
- Synchronized with method signatures
- Include parameter details

## Development Workflow

1. Analyze task specifications
2. Implement Clean Architecture
3. Write comprehensive tests
4. Ensure quality and documentation
5. Validate cross-repository integration

## Success Criteria

- Follows quality standards
- Comprehensive test suite
- Successful build
- Proper documentation
- Architectural consistency

## Restrictions

- No implementation without specification
- Maintain architectural integrity
- Prioritize code quality
- Follow .NET best practices
