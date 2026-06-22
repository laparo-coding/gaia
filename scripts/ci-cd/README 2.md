# CI/CD Scripts

This directory contains the helper scripts invoked by GitHub Actions and run
locally during development. Each script is self-contained and can be executed
directly.

## Scripts

### `codacy-standard-check.sh`

Local driver for the Codacy static-analysis quality gate. It runs the Codacy
CLI against the repository and applies an additive tool-selection policy
documented in `docs/ops/ci-cd-workflows.md` and
`docs/ops/ci-cd-quality-gates.md`.

**Usage**

```bash
./scripts/ci-cd/codacy-standard-check.sh                    # default: Sources, Tests
./scripts/ci-cd/codacy-standard-check.sh --skip-trivy       # skip security scan
./scripts/ci-cd/codacy-standard-check.sh --swift-only       # only Swift targets
./scripts/ci-cd/codacy-standard-check.sh app                 # explicit path
```

**Tool selection** (additive, in stable order)

| Path root             | Tools applied                          |
| --------------------- | -------------------------------------- |
| `Sources` / `Tests`   | `opengrep`, `trivy` (unless skipped)   |
| `app`, `web`, ...     | `opengrep`, `eslint`, `trivy` (unless skipped) |

The exact list of JS/TS roots, excluded paths, file extensions, and tool order
is configurable via [`codacy-tools.conf`](./codacy-tools.conf).

### `validate-controller-ipad-build.sh`

Builds the iOS controller app for an iPad simulator destination. Supports
`VALIDATION_MODE=single|dual-ipad` for sequential multi-device validation
runs.

### Other scripts

- `measure-controller-performance.sh` — captures controller perf metrics.
- `preflight-check.sh` — local readiness probe before opening a PR.
- `run-local-service-check.sh` — runs the Swift package + a live SSE smoke
  test on the local authentication service.
- `mock-aither-slides-server.py` / `mock-controller-bridge-server.py` —
  local HTTP mocks used by the controller integration tests.

## Configuration

### `codacy-tools.conf`

A shell-sourceable configuration file that controls which Codacy analyzers
are applied to which paths. The script reads it at startup and falls back to
identical built-in defaults if the file is missing, so policy drift between
environments is impossible.

```bash
ESLINT_ROOTS=(app web client frontend ui)
ESLINT_EXCLUDE_PATHS=("*/node_modules/*" "*/.next/*" "*/dist/*" "*/build/*")
ESLINT_EXTENSIONS=(js cjs mjs jsx ts tsx vue svelte)
TOOL_ORDER=(opengrep eslint trivy)
```

Add a new tool by appending its name to `TOOL_ORDER` and handling it in
`resolve_tool_args()` (or letting it fall through the default branch, which
passes it through unchanged).
