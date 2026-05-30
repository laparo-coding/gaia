# Hemera Testing Standards Addendum

This document provides detailed testing standards that supplement the Hemera Constitution.

## Unit Testing Standards

### Test Structure and Naming

```typescript
// File: tests/unit/component-name.spec.ts
import { test, expect } from '@playwright/test';

test.describe('ComponentName Unit Tests', () => {
  test('should render correctly with default props', async () => {
    // Arrange
    const props = { title: 'Test Title' };

    // Act
    const component = render(<ComponentName {...props} />);

    // Assert
    expect(component).toBeVisible();
  });
});
```

### Required Test Categories

1. **Component Rendering Tests**
   - Default state rendering
   - Props validation
   - State changes
   - Error boundaries

2. **Business Logic Tests**
   - Input validation
   - Data transformation
   - Edge cases
   - Error handling

3. **Authentication Tests**
   - User sign-in flows
   - Role-based access
   - Session management
   - Permission validation

4. **API Integration Tests**
   - Request/response validation
   - Error handling
   - Mock data scenarios
   - Rate limiting

### Coverage Requirements

- **Minimum Coverage**: 80% for all code
- **Critical Path Coverage**: 95% for authentication flows
- **Component Coverage**: 90% for UI components
- **Utility Coverage**: 100% for helper functions

## Prettier Testing Standards

### Formatting Validation

All code must pass Prettier formatting tests before commit:

```bash
# Run Prettier tests
npm run test:prettier

# Expected output:
🧪 Testing Prettier Configuration...
✅ Prettier configuration file exists
✅ Prettier ignore file exists
✅ Package.json has prettier scripts
✅ Prettier is installed as dev dependency
✅ Format check command works
✅ VSCode settings configured for Prettier
✅ GitHub Actions workflow exists
📊 Results: 7 passed, 0 failed
🎉 All Prettier tests passed!
```

### Prettier Configuration Standards

1. **Code Style Rules**
   - Single quotes for strings
   - Semicolons required
   - 80 character line width
   - 2 spaces for indentation
   - Trailing commas in ES5

2. **File Type Overrides**
   - Markdown: 100 character width, always wrap prose
   - JSON: 120 character width, 2 space indentation
   - YAML: 2 space indentation, double quotes

3. **Pre-commit Integration**
   - Husky pre-commit hooks automatically format staged files
   - lint-staged runs Prettier on relevant file types
   - Commits blocked if formatting fails

### CI/CD Integration

GitHub Actions workflows enforce Prettier compliance:

```yaml
# .github/workflows/code-formatting.yml
jobs:
  prettier:
    name: Prettier Check
    runs-on: ubuntu-latest
    steps:
      - name: Check Prettier Formatting
        run: npm run format:check
```

## Test-Driven Development Workflow

### Red-Green-Refactor Cycle

1. **Red Phase**: Write failing tests

   ```bash
   # Run tests - should fail
   npm run test:unit
   npm run test:e2e
   ```

2. **Green Phase**: Implement minimal code to pass tests

   ```bash
   # Tests should now pass
   npm run test:unit
   npm run test:prettier
   ```

3. **Refactor Phase**: Improve code while maintaining test coverage
   ```bash
   # All tests still pass after refactoring
   npm run test:unit
   npm run format:check
   npm run lint:ci
   ```

### Contract Testing Approach

Before implementing features, define contracts with failing tests:

```typescript
// tests/e2e/auth-protected-area.spec.ts
test('should redirect unauthenticated users to sign-in', async ({ page }) => {
  await page.goto('/protected/dashboard');
  await expect(page).toHaveURL(/\/sign-in/);
});
```

## Quality Gates Enforcement

### Pre-commit Hooks

```json
// package.json
{
  "lint-staged": {
    "*.{ts,tsx,js,jsx}": ["prettier --write", "eslint --max-warnings=0 --cache --fix"],
    "*.{json,yaml,yml}": ["prettier --write"],
    "*.{md,mdx}": ["prettier --write"]
  }
}
```

### GitHub Actions Gates

All PRs must pass these automated checks:

1. **Prettier Formatting**: `npm run format:check`
2. **ESLint Validation**: `npm run lint:ci`
3. **Unit Tests**: `npm run test:unit`
4. **E2E Tests**: `npm run e2e`
5. **Build Verification**: `npm run build`
6. **Type Checking**: `tsc --noEmit`

### Manual Review Requirements

1. **Code Review Checklist**
   - [ ] Unit tests cover new functionality
   - [ ] Prettier formatting is consistent
   - [ ] TypeScript types are properly defined
   - [ ] Authentication integration is secure
   - [ ] Performance impact is considered

2. **Testing Review**
   - [ ] Test cases cover edge cases
   - [ ] Mock data is realistic
   - [ ] Error scenarios are tested
   - [ ] Accessibility is validated

## Testing Tools and Setup

### Required Dependencies

```json
{
  "devDependencies": {
    "@playwright/test": "^1.48.2",
    "prettier": "^3.0.0",
    "eslint": "^8.57.0",
    "husky": "^8.0.0",
    "lint-staged": "^16.2.3"
  }
}
```

### Test Scripts

```json
{
  "scripts": {
    "test:unit": "playwright test tests/unit/",
    "test:e2e": "playwright test tests/e2e/",
    "test:prettier": "node tests/prettier-test-simple.js",
    "format": "prettier --write .",
    "format:check": "prettier --check .",
    "lint:ci": "eslint --cache --max-warnings=0 --ext .ts,.tsx,.js,.jsx ."
  }
}
```

### VSCode Configuration

Required VSCode settings for development:

```json
{
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": "explicit"
  },
  "prettier.requireConfig": true
}
```

## Compliance Monitoring

### Daily Development Workflow

1. **Before Coding**: Run `npm run test:prettier` to verify setup
2. **During Development**: Use VSCode auto-formatting and ESLint
3. **Before Commit**: Pre-commit hooks automatically format and test
4. **After Push**: GitHub Actions verify all quality gates

### Weekly Reviews

1. **Test Coverage Analysis**: Review coverage reports
2. **Code Quality Metrics**: Check ESLint and Prettier compliance
3. **Performance Benchmarks**: Validate authentication flow performance
4. **Security Scanning**: Review dependency vulnerabilities

### Constitutional Compliance

This testing addendum is part of the Hemera Constitution and must be followed for all development
activities. Any exceptions require explicit team approval and documentation.

**Version**: 1.0.0 | **Effective**: 2025-10-04 | **Review Date**: 2025-11-04
