## TypeScript / Node.js Backend Standards

### Language

- TypeScript always — never plain JavaScript
- Strict mode enabled (`"strict": true` in tsconfig)
- ESM modules with NodeNext resolution and explicit `.js` extensions on imports
- Target ES2022, Node.js >= 20
- Path alias `@/*` resolves to `src/*`

### Language Features

- Prefer `const` over `let`, never `var`
- Use arrow functions for callbacks
- Destructure objects and arrays
- Use optional chaining and nullish coalescing
- Avoid unnecessary dependencies
- Use async/await — never raw promises or callbacks
- Use `Decimal.js` for currency and precision arithmetic
- Use spread operator for conditional object fields ex: `...(value && { key: value })`

### Code Quality Rules

- Self-documenting code
- Avoid blank lines inside functions
- Files: kebab-case ex: `error-handler.ts`, `deposit-routes.ts`
- Classes: PascalCase ex: `DepositProvider`
- Functions and variables: camelCase ex: `createBilling`, `orderId`
- Constants: UPPER_SNAKE_CASE ex: `TOKEN_BUFFER_SECONDS`
- Interfaces and types: PascalCase ex: `DepositRequest`, `BaseApiResponse<T>`
- Maximum of three words combined in names
- No inline comments
- Fix all linting warnings
- Use ESLint with `@typescript-eslint` plugin

### Project Structure

```
src/
├── app.ts              (framework setup and route registration)
├── server.ts           (entry point)
├── config.ts           (env config validated with Zod)
├── middlewares/        (global error handlers)
├── routes/             (HTTP route handlers per domain)
├── services/           (shared utility services ex: logger, cache)
├── providers/          (external API integrations)
│   └── {name}/
│       ├── index.ts    (barrel exports)
│       ├── schemas.ts  (types and interfaces)
│       └── *.ts        (provider implementation)
└── schemas/            (API request/response types)
```

### Architecture Patterns

- DTOs defined as interfaces only — never classes
- Use discriminated union types for variants ex: `type Payer = PayerPf | PayerPj`
- Derive types from const values ex: `export type Config = typeof config`
- Module-level singletons for services with lazy initialization
- Barrel exports via `index.ts` per provider or module
- Config imported directly via module imports — no constructor injection

### HTTP Handler Pattern (Fastify)

- Register routes as async functions receiving `FastifyInstance`
- Use generic type parameters for request body and params ex: `app.post<{ Body: DepositRequest }>`
- Use request-scoped logger: `const log = request.log`
- Return structured `BaseApiResponse<T>` for all responses

### Error Handling

- Try-catch in all async route handlers with contextual logging
- Global error handler middleware for unhandled errors
- Silent degradation for non-critical services ex: cache misses return null
- Log errors with context object: `log.error({ err, orderId }, 'message')`

### Logging

- Use framework-provided logger (Fastify Pino) — never `console.log` in route handlers
- Structured log objects: `log.info({ key: value }, 'message')`
- Module-level log tags as constants: `const LOG_TAG = 'MODULE_NAME'`

### Testing Standards

- Vitest framework
- Test files use `.test.ts` suffix
- Comprehensive test coverage
- Meaningful test output
- Use fixtures for setup

### Documentation Requirements

- JSDoc for all public functions, classes, and interfaces
- Include `@param`, `@returns`, and `@throws` tags
- Synchronized with function signatures

## Development Workflow

1. Analyze task specifications
2. Implement layered architecture (routes → services → providers)
3. Validate config with Zod at startup
4. Write comprehensive tests
5. Ensure quality and documentation
6. Validate cross-repository integration

## Success Criteria

- Follows quality standards
- TypeScript strict mode with no errors
- Comprehensive test suite
- Successful build
- Proper documentation
- Architectural consistency

## Restrictions

- No implementation without specification
- Never use plain JavaScript — TypeScript only
- Maintain architectural integrity
- Prioritize code quality
- Follow Node.js/TypeScript best practices
