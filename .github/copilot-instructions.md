# gaia Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-05-30

## Active Technologies

- Swift 6.1 package manifest with Swift 6.x code targets + Foundation, SwiftPM modules (`GaiaCore`, `GaiaFeatureCatalog`), future authentication provider integration, server-side Bearer service credentials for Hemera and Aither (005-authentication)

## Project Structure

```
src/
tests/
```

## Commands

- `swift build` - Compile the package and all targets.
- `swift test` - Run all Swift test targets.
- `swift run <executable>` - Run an executable target (for example `swift run GaiaCLI`).
- `swift package update` - Update Swift package dependencies.
- `swift package dump-package` - Print the resolved manifest for inspection.

## Swift Style and .swift-format Conventions

- Use `.swift-format` as the source of truth for automated formatting and linting.
- Follow Swift API Design Guidelines:
	- Types use `UpperCamelCase`.
	- Functions, methods, and properties use `lowerCamelCase`.
- Prefer explicit access control (`public`, `internal`, `private`) over implicit defaults.
- Favor value types (`struct`, `enum`) where reference semantics are not required.
- Use `guard` for early exits and clear failure paths.
- Keep functions focused and limit complexity/length.
- Document public APIs with Swift doc comments (`///`).
- CI should run formatting/lint checks (`swift format lint`) and tests (`swift test`) to enforce consistency.

## Recent Changes

- 005-authentication: Added Swift 6.1 package manifest with Swift 6.x code targets + Foundation, SwiftPM modules (`GaiaCore`, `GaiaFeatureCatalog`), future authentication provider integration, server-side Bearer service credentials for Hemera and Aither

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
