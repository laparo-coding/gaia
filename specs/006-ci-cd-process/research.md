# Research: CI/CD Process for iPad-Only Distribution

## Decision 1: Split CI and deployment workflows

- Decision: Use one always-on CI workflow and one manually triggered deployment workflow.
- Rationale: This preserves fast feedback for every change while keeping release to device as a controlled operator action.
- Alternatives considered:
  - Single monolithic workflow for CI+CD: rejected due to reduced control and higher accidental release risk.

## Decision 2: Use ad hoc distribution artifacts, not App Store publication

- Decision: Build signed IPA artifacts for direct iPad installation without App Store listing.
- Rationale: Matches the explicit project constraint and avoids App Store review and release overhead.
- Alternatives considered:
  - TestFlight/App Store pipeline: rejected because App Store path is explicitly out of scope.

## Decision 3: Keep deployment gated by successful CI baseline

- Decision: Deployment can only target commits that have passed CI checks.
- Rationale: Prevents shipping unverified builds and keeps release quality predictable.
- Alternatives considered:
  - Unrestricted manual deployment from any commit: rejected due to high reliability risk.

## Decision 4: Mirror applicable Aither CI/CD quality and review gates

- Decision: Gaia CI/CD must inherit applicable Aither quality gates, including mandatory code-review checks before deployment.
- Rationale: Reuses a proven governance baseline and reduces policy drift across related systems.
- Alternatives considered:
  - Defining Gaia-only custom review thresholds: rejected due to avoidable divergence risk.

## Decision 5: Restrict deployment sources to semantic tags on main

- Decision: Deployment is allowed only from `vMAJOR.MINOR.PATCH` tags that point to `main`.
- Rationale: Ensures traceable, auditable release points and predictable rollback anchors.
- Alternatives considered:
  - Deploy from arbitrary green commits: rejected because release provenance would be weaker.

## Decision 6: Restrict deployment trigger to repository admins

- Decision: Only repository admins can manually trigger deployment.
- Rationale: Reduces accidental or unauthorized releases while staying simple for single-operator use.
- Alternatives considered:
  - Any write-access user can deploy: rejected due to broader risk surface.

## Decision 7: Treat artifacts as first-class rollback units

- Decision: Persist IPA, symbols, and release metadata for each deployment run.
- Rationale: Enables deterministic rollback without rebuilding old commits.
- Alternatives considered:
  - Rebuild older commits on demand: rejected due to non-determinism and slower recovery.

## Decision 8: Retain at least the last three successful release artifacts

- Decision: Keep at minimum the most recent three successful release artifact bundles.
- Rationale: Provides immediate rollback options beyond a single previous release while keeping storage bounded.
- Alternatives considered:
  - Keep only one artifact: rejected due to weak rollback resilience.

## Decision 9: Define explicit secret management expectations

- Decision: Document required secrets, ownership, and rotation playbook as part of the feature.
- Rationale: CI/CD reliability depends on durable signing and token handling.
- Alternatives considered:
  - Ad-hoc secret setup in personal notes: rejected because it is brittle and not auditable.