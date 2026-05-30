# Gaia

Gaia now ships with a VS Code-first Swift baseline built around Swift Package
Manager, swift-format, Swift Testing-compatible test targets, and Speckit. The
earlier web scaffold has been moved under `legacy/web-prototype/` so the Swift
package workflow is the only active root-level baseline for new work.

## Stack

- Swift 6+
- Swift Package Manager
- swift-format for formatting and linting
- Swift test targets prepared for Swift Testing / full Xcode toolchains
- Visual Studio Code with `swiftlang.swift-vscode` and LLDB DAP
- Speckit structure through `.specify/` and `specs/`

## Quickstart

```bash
cp .env.local.example .env.local
swift build
swift test
swift format lint --configuration .swift-format --strict Package.swift
swift format lint --configuration .swift-format --strict --recursive Sources Tests app/authentication
```

Rollbar is optional. Gaia initializes it automatically in both `GaiaCLI` and
`GaiaAuthenticationApp` when `GAIA_ROLLBAR_ACCESS_TOKEN` is set. If you prefer a
shared variable name across tools, `ROLLBAR_ACCESS_TOKEN` is also supported.
Gaia now loads a repo-local `.env.local` automatically, so you can keep the
`gaia` token out of your global shell profile. Values from the active shell
still override `.env.local` when both are set.
These two Gaia entry points are server-side or local developer processes, so
they should use a `post_server_item` token loaded from the environment. Do not
ship that token in a client app bundle.
Do not paste a token Public ID from the Rollbar UI into `.env.local`; Public
IDs are not secret tokens and cannot submit events. A `read` token is also the
wrong credential here: Gaia may initialize Rollbar with it, but event delivery
will fail with an insufficient privileges response from Rollbar's ingest API.
If Gaia later gains a real client-facing app target, that target must use a
client-side Rollbar token such as `post_client_item` via a separate client-safe
configuration path.
For short-lived processes such as `GaiaCLI`, Gaia waits 1 second on shutdown so
the Rollbar Apple SDK can finish async delivery. Override this with
`GAIA_ROLLBAR_DELIVERY_WAIT_SECONDS` or `ROLLBAR_DELIVERY_WAIT_SECONDS` if you
need a different drain window.
Gaia also writes a local Rollbar diagnosis to stderr by default in development
and test so you can see whether initialization was skipped or which environment
was selected. You can force this on or off with `GAIA_ROLLBAR_DIAGNOSTICS` or
`ROLLBAR_DIAGNOSTICS`.

If `swift test` fails with a missing `Testing` module on macOS, switch from the
standalone Command Line Tools to a full Xcode toolchain. Build and lint work
with Command Line Tools alone; SwiftPM tests may require the full Xcode SDK.

## Authentication Foundation

- `Sources/GaiaCore/Authentication/` contains the interactive session model,
	authorization rules, per-service Bearer credential handling, retry-on-expiry
	coordination, and secret-safe telemetry for Hemera and Aither.
- `InteractiveAuthenticationProvider.swift` and `AuthenticationRuntime.swift`
	now provide the concrete runtime hook between the interactive provider,
	session manager, and downstream service authorization flow.
- `app/authentication/` contains the file-based route and page surface for the
	planned authentication entry point, session lifecycle, and internal service
	authorization contracts.
- `swift run GaiaAuthenticationApp --port 8080` starts a local HTTP shell for
	`/authentication` and the planned `/api/auth/*` endpoints.
- The authentication design follows the same server-side Bearer token procedure
	that Aither uses for Hemera API access: separate credentials for Hemera and
	Aither, short-lived cache entries, and a single refresh-and-retry cycle on
	downstream expiry.

## Recommended VS Code Extensions

- `swiftlang.swift-vscode`
- `llvm-vs-code-extensions.lldb-dap`

## Project Structure

```text
.github/workflows/
.vscode/
Documentation.docc/
app/
legacy/web-prototype/
Sources/
Tests/
specs/
Package.swift
```

## Speckit Workflow

1. Capture the feature in `specs/<id-slug>/spec.md`.
2. Generate `plan.md` from the approved spec.
3. Generate `tasks.md` from the approved plan.
4. Implement only after specs, plan, and tasks exist.

Templates and workflow files live under `.specify/`.

## Common Commands

```bash
swift build
swift run GaiaAuthenticationApp --port 8080
swift run GaiaCLI
swift run GaiaCLI --json
./scripts/run-local-service-check.sh
swift run GaiaCLI --json | jq '.schemaVersion'
swift run GaiaCLI new-feature feature-catalog-discovery "Feature Catalog Discovery"
swift run GaiaCLI new-feature cli-option-support --title "CLI Option Support" --summary "Add summary, description, and dry-run support." --description "Create richer feature scaffolds from CLI arguments." --dry-run
swift run GaiaCLI new-feature cli-option-support -t "CLI Option Support" -s "Add summary, description, and dry-run support." -d "Create richer feature scaffolds from CLI arguments." -n
swift run GaiaCLI new-feature cli-json-preview -t "CLI JSON Preview" -s "Add machine-readable output and focused dry-run previews." -d "Emit JSON status output and allow previewing individual scaffold files." -n -p spec.md --json
swift run GaiaCLI new-feature authentication -t "Authentication" -s "Define the first authentication foundation for Gaia." -d "Plan sign-in, sign-out, session handling, and protected-route access." -n -p spec.md -p tasks.md -P execution --json
swift test
swift format format --configuration .swift-format --in-place Package.swift
swift format format --configuration .swift-format --in-place --recursive Sources Tests app/authentication
swift format lint --configuration .swift-format --strict Package.swift
swift format lint --configuration .swift-format --strict --recursive Sources Tests app/authentication
curl http://127.0.0.1:8080/authentication
curl -X POST http://127.0.0.1:8080/api/auth/sign-in -H 'Content-Type: application/json' -d '{"returnToPath":"/dashboard"}'
```

For the live Hemera/Aither integration check, use `./scripts/run-local-service-check.sh` or the VS Code task `Swift Run GaiaCLI Service Check (local env)`. The wrapper reads `HEMERA_SERVICE_API_KEY` from the sibling Hemera repo and `AITHER_SYNC_TOKEN` from the sibling Aither repo, so no manual shell export is required.

## CI/CD Process Summary (006)

- CI and deployment are split into separate workflows.
- CI enforces format/lint, build, test, and review-gate checks.
- Deployment is manual (`workflow_dispatch`) and restricted to repository admins.
- Deployment source must be a `vMAJOR.MINOR.PATCH` tag on `main` with a successful CI baseline.
- Every successful deployment produces IPA, symbols, and metadata artifacts.
- At least the latest three successful artifact bundles are retained for rollback.

## Legacy Prototype

The archived Next.js scaffold now lives in `legacy/web-prototype/`. It is kept
for reference only and is not part of the active Swift build, validation, or CI
path.

## CLI Output Notes

- JSON responses now include `schemaVersion: "1.0"` for stable downstream parsing.
- Preview selection accepts repeated `--preview` or `-p` options.
- Preview profiles are available through `--preview-profile` or `-P` with `all`, `planning`, `overview`, and `execution`.
