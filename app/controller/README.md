# Gaia Controller iPad Scaffold

This folder hosts the iPad controller shell for the controller-design feature.

## Current scaffold

- `GaiaControllerApp.swift` provides a minimal SwiftUI app entry point scaffold.
- The concrete split-layout controller views are implemented in later tasks.

## Reproducible build validation (iPad landscape)

Use Xcode build tooling against an iPad simulator destination:

```bash
xcodebuild \
  -project GaiaControllerApp.xcodeproj \
  -scheme GaiaControllerApp \
  -destination 'generic/platform=iOS Simulator' \
  build
```

If your project uses a workspace, replace `-project` with `-workspace <name>.xcworkspace`.

Landscape validation expectation:

- The build completes with `** BUILD SUCCEEDED **`.
- The target is configured for iPad landscape mode; confirm runtime launch behavior separately.
