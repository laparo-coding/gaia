# CI/CD Quality Gates

## Mandatory CI Gates

1. `swift format lint` for `Package.swift`, `Sources`, `Tests`, and `app/authentication`
2. `swift build`
3. `swift test`
4. Review gate checks aligned with the subset of Aither rules that apply to Gaia (human approval, automated review pass, and zero unresolved blocking comments; see `specs/006-ci-cd-process/spec.md` FR-011)

## Review Gate Policy

Deployment requires all of the following:

- human approval present
- automated review gate passed
- zero unresolved blocking comments

## Merge and Deploy Rules

- Merge remains blocked while any required CI gate is failing.
- Deployment requires successful CI baseline on a semver tag on `main`.
- Deployment trigger is restricted to repository admins.

## Operator Checklist

1. Verify CI status is green on the release tag commit.
2. Verify review gate conditions are satisfied.
3. Verify signing secrets are present and not expired.
