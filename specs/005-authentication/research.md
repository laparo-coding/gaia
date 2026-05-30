# Research: Authentication

## Decision 1: Use a hybrid workspace structure for the feature

- Decision: Keep auth domain logic in SwiftPM targets under `Sources/` and reserve `app/authentication/` for the future user-facing surface.
- Rationale: Gaia already uses SwiftPM as the canonical build path, while the repository also contains an `app/` surface for future product work.
- Alternatives considered: Pure SwiftPM-only delivery with no `app/` surface; rejected because the spec already includes an interactive user-facing auth flow.

## Decision 2: Mirror Aither's server-side Bearer token pattern for both downstream services

- Decision: Gaia authenticates to Hemera and Aither with dedicated server-side Bearer credentials loaded from environment variables or a secrets manager.
- Rationale: This exactly matches the clarified requirement and aligns Gaia's service-to-service auth with the Aither -> Hemera integration pattern.
- Alternatives considered: Interactive user session tokens and static API-key flows without Bearer semantics; rejected because they either weaken the server boundary or diverge from the chosen Aither pattern.

## Decision 3: Keep a separate token cache per downstream target

- Decision: Model distinct cache entries and expiry state for Hemera and Aither instead of one shared cross-service token bucket.
- Rationale: Each downstream may have different audiences, expiry windows, and failure modes, and Gaia must be able to recover from one service failing without corrupting the other's auth state.
- Alternatives considered: One shared service token cache; rejected because it couples unrelated downstream auth lifecycles.

## Decision 4: Limit retry-on-expiry to one refresh attempt per failed request

- Decision: On `401` or `WWW-Authenticate`, Gaia refreshes the affected downstream credential once and retries the request one time.
- Rationale: This preserves resilience while avoiding retry storms and keeping failure handling deterministic.
- Alternatives considered: No retry, or unlimited retries; rejected because no retry hurts resilience and unlimited retries risks loops and noisy failures.

## Decision 5: Use Swift Testing-style target conventions and Xcode-backed local test execution

- Decision: Continue with the repository's existing Swift Testing-oriented test targets and document that local `swift test` expects a full Xcode toolchain.
- Rationale: Gaia already standardizes on this approach in its current SwiftPM baseline and VS Code tasks.
- Alternatives considered: Introduce XCTest-only targets for this feature; rejected because it would fragment conventions.
