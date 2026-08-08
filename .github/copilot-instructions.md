# gaia Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-08-02

## Active Technologies
- Swift 6.x (package targets), Swift 6.1 manifest, SwiftPM only, Foundation (`URLSession`), existing (009-real-data-connections)
- In-memory `DashboardCache` (short-lived snapshot cache, TTL 30-60s) (009-real-data-connections)
- Swift 6.x (package targets), Swift 6.1 manifest, SwiftPM, Foundation (`URLSession`), SwiftUI controller (010-timestamp-playback)
- In-memory chapter list cache (short-lived, per-assetId, TTL ≤ 60s) (010-timestamp-playback)
- Swift 6.x (package targets), Swift 6.1 manifest, SwiftPM, Foundation (`URLSession`), AVFoundation/AVKit, SSE playback command monitor, `PlaybackCommandDelegate` (011-playback-sync)
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
- 011-playback-sync: Added Swift 6.x (package targets), Swift 6.1 manifest, SwiftPM, Foundation (`URLSession`), AVFoundation/AVKit, SSE playback command monitor, `PlaybackCommandDelegate`
- 010-timestamp-playback: Added Swift 6.x (package targets), Swift 6.1 manifest, SwiftPM, Foundation (`URLSession`), SwiftUI controller, in-memory chapter list cache (per-assetId, TTL ≤ 60s)
- 009-real-data-connections: Added Swift 6.x (package targets), Swift 6.1 manifest, SwiftPM only, Foundation (`URLSession`), existing


<!-- MANUAL ADDITIONS START -->
## Caveman Mode (Manual)

- Reference: `.github/caveman-mode.md`.

<!-- MANUAL ADDITIONS END -->

<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan:
`specs/011-playback-sync/plan.md`
<!-- SPECKIT END -->
