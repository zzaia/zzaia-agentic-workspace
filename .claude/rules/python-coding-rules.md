## Python Language Standards

### Language Features

- Use type hints for all functions
- Prefer `datetime.now(timezone.utc)`
- Use f-strings for formatting
- Use explicit type annotations
- Avoid unnecessary arguments
- Avoid unnecessary package dependencies
- Use dataclasses for data structures

### Code Quality Rules

- Self-documenting code
- Avoid blank lines inside functions
- Clear naming conventions with snake_case
- Maximum of three words combined in names ex: `create_bank_account`, `bank_reference_code`
- Use `async` prefix for coroutine functions
- No inline comments
- No inline spaces
- Fix linting warnings

### Testing Standards

- Pytest framework
- Comprehensive test coverage
- Meaningful test output
- Use fixtures for setup

### Documentation Requirements

- Docstrings for all public functions, classes, and methods
- Synchronized with function signatures
- Include Args, Returns, and Raises sections
- Document all parameters with types and descriptions
- Document all properties and attributes

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
- Follow Python best practices
