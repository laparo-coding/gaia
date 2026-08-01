# Gaia Controller iPad Scaffold

This folder hosts the iPad controller shell for the controller-design feature.

## Current scaffold

- `GaiaControllerApp.swift` provides a minimal SwiftUI app entry point scaffold.
- The concrete split-layout controller views are implemented in later tasks.

## Reproducible build validation (iPad landscape)

Use SwiftPM with the CI build script (targets iPadOS arm64):

```bash
bash scripts/ci-cd/build-ipados-swiftpm.sh
```

Or run a quick host compile check (does **not** validate iPadOS):

```bash
swift build --product GaiaControllerApp
```

Landscape validation expectation:

- The build completes successfully.
- The target is configured for iPad landscape mode; confirm runtime launch behavior separately.
