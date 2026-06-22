# Refactor: `RuntimeSessionState` — Decision Record

**Date:** 2026-06-09
**Spec:** 008-dashboard
**Status:** Decision recorded, no code change required
**Scope:** `Sources/GaiaCore/Authentication/RuntimeSessionState.swift` and its
Xcode project references.

---

## Context

`RuntimeSessionState` is a small value type in `GaiaCore` that projects a
subset of `UserSession` fields for use in the view / policy / route-handler
layer. It is currently referenced from five call sites:

| Caller (file)                                                                              | Purpose                                                  |
| ------------------------------------------------------------------------------------------ | -------------------------------------------------------- |
| `Sources/GaiaCore/Authentication/AuthenticationRuntime.swift`                              | API: read / sign-in / sign-out return type               |
| `Sources/GaiaCore/Dashboard/SeminarStartPolicy.swift`                                      | Policy input                                            |
| `app/controller/DashboardViewModel.swift`                                                  | Constructed locally from `UserSession` for policy check  |
| `app/authentication/main.swift`                                                            | Controller-session authorization + HTML rendering        |
| `app/authentication/page.swift`                                                            | `AuthenticationPageState` mapping                        |

The type exposes exactly five fields: `status`, `subjectId`, `role`,
`expiresAt`, `returnToPath`. It deliberately omits `sessionId` and `issuedAt`
which exist on `UserSession` but are not relevant outside the runtime layer.

The question to answer: **Should `RuntimeSessionState` be inlined into
`UserSession`, deprecated, or kept as-is?**

---

## Audit findings

### 1. Field usage

All five callers consume the same five fields exposed by
`RuntimeSessionState`. None of them require `sessionId` or `issuedAt`. Inlining
the type into `UserSession` would re-couple the view layer to internal fields
that have no business there.

### 2. Construction cost

`RuntimeSessionState(session:)` is a single-line initializer that copies five
fields. It is **not** a translation layer (no transformation, no validation,
no derivation). It is, however, a deliberate view-projection.

### 3. Xcode project references

All four pbxproj entries for `RuntimeSessionState.swift` are required and
non-redundant:

| Section                  | Role                                                          | Required? |
| ------------------------ | ------------------------------------------------------------- | --------- |
| `PBXBuildFile`           | Compiles the file into the `GaiaControllerApp` target         | Yes       |
| `PBXFileReference`       | Binds the build file to the on-disk path                      | Yes       |
| `PBXGroup (GaiaCoreSources)` | Surfaces the file in the Xcode navigator                | Yes       |
| `PBXSourcesBuildPhase`   | Adds the file to the actual compile phase                     | Yes       |

Removing any of them would either silently drop the file from compilation
or break the Xcode project graph. **No cleanup action is required here.**

### 4. Test coverage

The constructor and equality semantics are exercised indirectly through
`AuthenticationRuntime` and `SeminarStartPolicy` tests. No dedicated test
file exists for `RuntimeSessionState` itself; the value type is trivial
enough that the integration coverage is sufficient.

---

## Decision

**Keep `RuntimeSessionState` as-is.** It is a deliberate view-projection that
shields the view / policy / route-handler layer from internal `UserSession`
fields. Inlining it would be a regression in encapsulation.

### Why not "deprecate and remove later"?

- The type has no performance or correctness cost.
- Removing it would force every caller to either access the wider
  `UserSession` (leaking `sessionId` and `issuedAt` into the view layer) or
  to create a new ad-hoc projection at each call site.
- There is no migration pressure (no external API, no public consumers
  outside this repository).

### Why not "promote to first-class domain type"?

The current shape already matches what callers need. Promoting it would
either duplicate the constructor pattern or push view-layer concerns into
`GaiaCore.Authentication`.

---

## Consequences

- `RuntimeSessionState` stays in `GaiaCore.Authentication` with its current
  initializer and field set.
- The Xcode project keeps the four existing references for the file.
- Future contributors are expected to **add** new fields to
  `UserSession` (not `RuntimeSessionState`) when extending authentication,
  and to extend the initializer projection if a new field becomes
  view-relevant.
- If a future refactor introduces a second view-projection (e.g. for the
  public dashboard or for telemetry), consider extracting a small
  `SessionProjection` protocol rather than adding more one-off types.

---

## Verification

- `swift build` — passes (the file is part of the SwiftPM target).
- `swift test` — all suites that exercise authentication still pass.
- `xcodebuild -scheme GaiaControllerApp -destination 'generic/platform=iOS Simulator' build`
  — passes (the four pbxproj references resolve the file correctly).
