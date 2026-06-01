# CI/CD Quality Gates

## Automated CI Pipeline (`.github/workflows/ci.yml`)

All PRs to `main` and pushes to `main` trigger the **Gaia CI** workflow on `macos-15`:

1. **Swift Format Lint**
   - `Package.swift`, `Sources/`, `Tests/`, and `app/authentication/` are checked with `swift-format` in strict mode
   - Formatter config: `.swift-format`
   - If lint fails: CI blocks merge

2. **Swift Build**
   - Full package compilation: `swift build`
   - Validates code compiles without errors

3. **Swift Test**
   - Runs test suite with red-phase controller tests skipped (see **Red-Phase Strategy** below)
   - Command: `swift test --skip [list of controller test suites]`
   - Failing tests block merge

4. **Required Status Check: `quality`**
   - GitHub status check name: `quality` (from ci.yml job)
   - All three steps above must pass
   - Branch protection enforces this

## Required Status Checks for Main Branch

Branch protection on `main` requires **4 status checks** before merge is allowed:

| Check | Source | Purpose | Enforced |
|-------|--------|---------|----------|
| `quality` | `.github/workflows/ci.yml` | Build, test, lint | ✅ Yes |
| `CodeRabbit` | GitHub App | Swift-focused code review | ✅ Yes |
| `Qodo` | GitHub App | Code structure & contract validation | ✅ Yes |
| `Codacy Static Code Analysis` | GitHub App | Static analysis, security scanning | ✅ Yes |

Additionally:
- **Linear history required:** Merge commits not allowed; use squash or rebase
- **Conversation resolution required:** All PR discussions must be resolved before merge
- **Dismiss stale reviews:** Unchecking this means reviews remain valid even after new commits

## Automated Code Review Apps

### Qodo Code Review
- **Trigger:** Installed GitHub App, runs on all PRs to `main`
- **Output:** Reviews contract compliance, identifies bugs (3 bugs reported on PR #3)
- **Config:** No local configuration file; settings managed in Qodo dashboard
- **Blocking:** Can flag issues but does not block merge (advisory)

### CodeRabbit
- **Trigger:** Installed GitHub App, runs on all PRs to `main`
- **Output:** Swift-focused code review with `assertive` tone
- **Config:** `.coderabbit.yaml` — profile, summary settings, language-specific guidance
- **Blocking:** Can comment but does not block merge (advisory)

### Codacy Static Analysis
- **Trigger:** Installed GitHub App with repository integration
- **Output:** ErrorProne issues, duplication metrics, complexity metrics, security (trivy)
- **Config:** `.codacy/codacy.yaml` — tool enablement, runtime versions
- **CLI:** `.codacy/cli.sh` — v2 binary management script
- **Blocking:** Required status check `Codacy Static Code Analysis`; must pass for merge

## Red-Phase Test Strategy

Controller feature tests are intentionally excluded from CI to unblock development:

**Skipped test suites:**
- `ControllerContractTests`
- `ControllerErrorStateScenarioTests`
- `ControllerInitialLoadScenarioTests`
- `ControllerNavigationStateTests`
- `ControllerNavigationScenarioTests`
- `ControllerPlaceholderNotesScenarioTests`
- `ControllerNotesOverflowScenarioTests`
- `ControllerInputPolicyScenarioTests`
- `ControllerSessionTests`
- `ControllerBridgeRouteTests`
- `AitherControllerClientTests`

**Rationale:** These tests contain intentional `#expect(false)` placeholders during red-phase development. They will be re-enabled once controller feature implementation reaches acceptance phase.

**Manual validation:** `.github/workflows/swift-quality.yml` (workflow_dispatch mode) runs full test suite without skips for explicit validation.

## Merge and Deployment Rules

- Merge is blocked while any of the 4 required status checks is failing
- Deployment requires successful CI baseline on a semver tag on `main`
- Deployment trigger is restricted to repository admins
- All PR conversations must be marked resolved before merge is allowed

## Local Quality Validation

To validate locally before pushing (equivalent to CI checks):

```bash
# Format lint (same as CI)
swift format lint --configuration .swift-format --strict Package.swift
swift format lint --configuration .swift-format --strict --recursive Sources Tests app/authentication

# Build (same as CI)
swift build

# Test with red-phase skips (same as CI)
swift test --skip ControllerContractTests --skip ControllerErrorStateScenarioTests \
  --skip ControllerInitialLoadScenarioTests --skip ControllerNavigationStateTests \
  --skip ControllerNavigationScenarioTests --skip ControllerPlaceholderNotesScenarioTests \
  --skip ControllerNotesOverflowScenarioTests --skip ControllerInputPolicyScenarioTests \
  --skip ControllerSessionTests --skip ControllerBridgeRouteTests --skip AitherControllerClientTests

# Full test suite (for manual verification only)
swift test  # Includes all red-phase tests
```

## Code Quality Checks Not Blocking Merge

- Complexity metric (725 lines max per entity)
- Duplication metric (% of duplicated code)
- Code coverage (% of lines tested)

These are reported by Codacy but do not prevent merge. Refactoring is recommended once core features stabilize.

## Operator Checklist (Before Release)

1. Verify all 4 status checks are green on the release tag commit
2. Verify all PR conversations are resolved
3. Verify code review sign-offs are present (Qodo, CodeRabbit optional, Codacy required)
4. Verify signing secrets are present and not expired
5. Run full test suite locally: `swift test` (without --skip flags)
