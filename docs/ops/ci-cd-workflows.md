# GitHub Actions Workflows

## Workflow Files

Two workflows are defined in `.github/workflows/`:

1. **ci.yml** — Primary automated CI/CD pipeline
2. **swift-quality.yml** — Manual/reusable quality validation

## ci.yml: Gaia CI (Automatic)

**Trigger:**
- `pull_request` to `main`
- `push` to `main`

**Runner:** `macos-15`

**Jobs:**

### Job: `quality`

Runs sequentially on every PR and push to main:

1. **Checkout** — Fetch repository code (`actions/checkout@v4`)

2. **Select Xcode 16.4** — Set Swift toolchain
   ```bash
   sudo xcode-select -s /Applications/Xcode_16.4.app
   ```

3. **Swift Format Lint** — Validate code style
   ```bash
   swift format lint --configuration .swift-format --strict Package.swift
   swift format lint --configuration .swift-format --strict --recursive Sources Tests app/authentication
   ```
   - Enforces `.swift-format` configuration
   - `--strict` mode: violations cause failure
   - **Failure:** Blocks CI and PR merge

4. **Build** — Compile Swift package
   ```bash
   swift build
   ```
   - Validates all targets compile
   - **Failure:** Blocks CI and PR merge

5. **Test** — Run test suite (red-phase skipped)
   ```bash
   swift test --skip ControllerContractTests --skip ControllerErrorStateScenarioTests \
     --skip ControllerInitialLoadScenarioTests --skip ControllerNavigationStateTests \
     --skip ControllerNavigationScenarioTests --skip ControllerPlaceholderNotesScenarioTests \
     --skip ControllerNotesOverflowScenarioTests --skip ControllerInputPolicyScenarioTests \
     --skip ControllerSessionTests --skip ControllerBridgeRouteTests \
     --skip AitherControllerClientTests
   ```
   - Skips intentional placeholder tests (red-phase feature development)
   - **Failure:** Blocks CI and PR merge

**Status Check:** `quality`
- Passed if all steps complete successfully
- Required by branch protection on `main`

---

## swift-quality.yml: Swift Quality (Manual)

**Trigger:**
- `workflow_dispatch` — Manual trigger from GitHub UI
- `workflow_call` — Reusable workflow call from other workflows

**Runner:** `macos-15`

**Jobs:**

### Job: `quality`

Runs full validation without skipping tests:

1. **Checkout** — Fetch code
2. **Set up Xcode 16.4** — Using `maxim-lobanov/setup-xcode@v1`
3. **Verify toolchain** — Print versions
   ```bash
   xcodebuild -version
   swift --version
   ```
4. **Build** — Full compilation
5. **Test** — Full test suite (includes red-phase tests)
6. **Lint Package Manifest**
7. **Lint Sources and Tests**

**When to use:**
- Manual verification before releases
- Testing full suite in controlled environment
- Debugging test failures in red-phase features

**Trigger example:**
```bash
gh workflow run swift-quality.yml
```

---

## Branch Protection Rules on `main`

Configured in GitHub repository settings:

| Setting | Value | Purpose |
|---------|-------|---------|
| Require pull request reviews | 1 reviewer (can be admin) | Code review gate |
| Dismiss stale pull request approvals | Unchecked | Reviews persist after commits |
| Require status checks to pass | 4 checks (see below) | CI quality gates |
| Require branches to be up to date | ✅ Checked | Prevents merge of stale branches |
| Require code reviews | ✅ Yes | Human approval needed |
| Linear history | ✅ Checked | No merge commits; squash/rebase only |
| Allow force pushes | Disabled | Prevents accidental overwrite |
| Allow deletions | Disabled | Protects main branch |

### Required Status Checks (4)

1. **quality** — `.github/workflows/ci.yml`
   - Lint, build, test (red-phase skipped)
   - Must pass before merge

2. **CodeRabbit** — GitHub App
   - Swift-focused code review
   - Configuration: `.coderabbit.yaml`
   - Does not block merge (advisory)

3. **Qodo** — GitHub App
   - Code structure and contract validation
   - Does not block merge (advisory)

4. **Codacy Static Code Analysis** — GitHub App
   - Static analysis, security (trivy), duplication, complexity
   - Configuration: `.codacy/codacy.yaml`
   - CLI script: `.codacy/cli.sh`
   - Does not block merge (advisory)

---

## GitHub Apps Integration

### Qodo Code Review

- **Installation:** GitHub App registered on repository
- **Trigger:** PR opens or commits pushed to PR
- **Output:** Comments on PR with findings (bugs, rule violations)
- **Config:** Dashboard (Qodo website)
- **No local files required**

### CodeRabbit

- **Installation:** GitHub App registered on repository
- **Trigger:** PR opens or commits pushed to PR
- **Output:** Comments on PR with code review feedback
- **Config:** `.coderabbit.yaml` (local)
  ```yaml
  profile: assertive
  high_level_summary: true
  collapse_walkthrough: false
  tone_instructions: "Emphasize Swift type safety, actor/concurrency patterns, etc."
  ```

### Codacy

- **Installation:** GitHub App registered on repository
- **Setup:** Repository linked in Codacy dashboard
- **Trigger:** PR opens or commits pushed to PR
- **Output:** Comments on PR with issues, metrics
- **Config:** `.codacy/codacy.yaml` (local)
  ```yaml
  tools:
    - eslint
    - lizard
    - opengrep
    - trivy  # Security scanning
  runtimes:
    - node@22.2.0
    - python@3.11.11
  ```
- **CLI:** `.codacy/cli.sh` manages v2 binary
  - Downloads on demand
  - Caches locally
- **Local script behavior:** `scripts/ci-cd/codacy-standard-check.sh`
   - Always runs `opengrep` for baseline static analysis (consistent path coverage)
   - Adds `eslint` when JS/TS files are present in canonical JS/TS source roots
     (`app/`, `web/`, `client/`, `frontend/`, `ui/`); ignores build/dependency
     artifacts (`node_modules`, `.next`, `dist`, `build`) and Swift roots
     (`Sources/`, `Tests/`) even if they incidentally contain JS/TS contract specs
   - Adds `trivy` by default for security scan; disabled only with `--skip-trivy`
   - Uses additive tool selection to avoid coverage gaps caused by mutually exclusive tool picks
   - Per-tool invocations are sequential to bypass the Codacy CLI's exclusive
     `--tool` handling, preserving a stable order:
     `opengrep` → `eslint` (when applicable) → `trivy` (when not skipped)
   - Tool selection is driven by the external config
     `scripts/ci-cd/codacy-tools.conf` (`ESLINT_ROOTS`, `ESLINT_EXCLUDE_PATHS`,
     `ESLINT_EXTENSIONS`, `TOOL_ORDER`); the script falls back to identical
     built-in defaults if the config is missing

---

## Removed Workflows

The following workflows are **no longer used**:

1. **qodo-pr-agent.yml** — Deleted
   - Was: Triggered Qodo to create PRs for issues
   - Replaced by: Qodo GitHub App (installed review)

2. **codacy-review.yml** — Deleted
   - Was: Triggered Codacy manual reviews
   - Replaced by: Codacy GitHub App (automatic on PR)

**Reason:** Consolidation to app-based reviewers eliminates need for workflow-based triggers.

---

## Development Workflow (Local)

1. **Create feature branch**
   ```bash
   git checkout -b feature/my-feature
   ```

2. **Make changes and commit**
   ```bash
   git add -A
   git commit -m "feat: description"
   ```

3. **Validate locally (optional)**
   ```bash
   swift format lint --configuration .swift-format --strict --recursive Sources Tests app/authentication
   swift build
   swift test --skip ControllerContractTests --skip ... (all skips from ci.yml)
   ```

4. **Push to remote**
   ```bash
   git push origin feature/my-feature
   ```

5. **Create PR** — GitHub UI or CLI
   ```bash
   gh pr create --base main --fill
   ```

6. **Automated checks run**
   - `quality` job (lint, build, test)
   - CodeRabbit review
   - Qodo review
   - Codacy analysis

7. **Address feedback and push commits**
   - CI re-runs on each push
   - Status checks update

8. **Merge when ready**
   - All 4 status checks green
   - Reviews approved
   - Conversations resolved
   - Branch up to date

---

## Troubleshooting

### CI Fails: Format Lint

**Problem:** `swift format lint` fails
- **Solution:** Run locally and fix: `swift format -i --configuration .swift-format Sources Tests app/authentication`

### CI Fails: Build

**Problem:** Compilation error
- **Cause:** Usually missing import, type error, or syntax
- **Solution:** Run `swift build` locally, fix errors

### CI Fails: Test

**Problem:** Test fails that isn't in skip list
- **Cause:** Regression in non-red-phase test
- **Solution:** Investigate, fix, commit, re-push

### CI Fails: Red-Phase Tests Run

**Problem:** Controller tests suddenly fail when they should be skipped
- **Cause:** ci.yml `--skip` list is outdated
- **Solution:** Update skip list in ci.yml, commit, re-push

### Status Check Stuck

**Problem:** `quality` status check doesn't update
- **Cause:** Workflow still running, or GitHub cache issue
- **Solution:** Wait 2-5 minutes, or re-push a commit to trigger fresh run

### Merge Blocked by Status Check

**Problem:** Can't merge even though CI appears green
- **Cause:** One of 4 status checks is still running or failed (check Details)
- **Solution:** Click "Details" on each check to see logs; fix and re-push

---

## Status Check Details Links

From PR page, click "Details" next to each check to view:

| Check | Link Opens |
|-------|-----------|
| `quality` | GitHub Actions workflow logs (ci.yml) |
| `CodeRabbit` | CodeRabbit dashboard review (external) |
| `Qodo` | Qodo dashboard review (external) |
| `Codacy Static Code Analysis` | Codacy dashboard (external) |

---

## Security Considerations

- **Credentials:** CI does not handle deployment or secrets (only build/test)
- **Signing:** PRs are not signed by default (future improvement)
- **Permissions:** GitHub App permissions are minimal (read PRs, post comments)
- **Code injection:** Workflows avoid `eval()` and use safe command execution
