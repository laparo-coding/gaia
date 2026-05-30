# Gaia

Gaia is a VS Code-first Swift project baseline with a Speckit workflow.

## Workflow

1. Write `spec.md`.
2. Generate `plan.md`.
3. Generate `tasks.md`.
4. Implement only after the first three artifacts exist.

## Quality Gates

- `swift build`
- `swift test`
- `swift format lint --configuration .swift-format --strict Package.swift`
- `swift format lint --configuration .swift-format --strict --recursive Sources Tests app/authentication`

## Authentication

- `Sources/GaiaCore/Authentication/` provides the session model, access rules,
	service credential cache, Hemera and Aither authenticators, retry-on-expiry
	coordination, and telemetry.
- `AuthenticationRuntime` composes the interactive provider, session manager,
	and downstream service coordinator into one runtime boundary for the app
	surface.
- `app/authentication/` defines the planned file-based surface for
	`/api/auth/session`, `/api/auth/sign-in`, `/api/auth/service/hemera/authorize`,
	`/api/auth/service/aither/authorize`, and the authentication entry page.
- `GaiaAuthenticationApp` compiles the authentication surface into a local HTTP
	shell that can be run from SwiftPM for development-time validation.
- Service-to-service requests use server-side Bearer credentials sourced from
	environment variables or secrets, never an interactive user session token.