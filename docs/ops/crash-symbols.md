# Crash Symbol Publication

## Goal

Ensure symbols are captured and published alongside each deployment artifact bundle so post-release crash diagnostics remain actionable.

## Required Outputs Per Release

- signed IPA
- symbols archive (`dSYM` or equivalent)
- metadata file including commit SHA, tag, and timestamp

## Publication Flow

1. Generate symbols during archive/sign pipeline.
2. Store symbols in release artifact storage with stable naming.
3. Include symbols reference in release metadata.
4. Verify symbols bundle integrity before marking deployment successful.

## Retention

- Keep symbols for at least the latest three successful releases.
- Align symbols retention with rollback candidate retention.
