# CI/CD Secret Inventory

## Required Secrets

- `IOS_TEAM_ID`: Apple Developer Team ID
- `IOS_BUNDLE_ID`: App bundle identifier
- `IOS_CERTIFICATE_BASE64`: Signing certificate payload
- `IOS_CERTIFICATE_PASSWORD`: Signing certificate password
- `IOS_PROVISIONING_PROFILE_BASE64`: Provisioning profile payload
- `IOS_KEYCHAIN_PASSWORD`: Temporary keychain password for CI runner

## Optional Secrets

- `APPLE_ID` and app-specific credentials if needed by signing helper scripts

## Ownership

- Owner: Repository admins
- Rotation cadence: every 90 days or immediately after compromise indicators
- Storage: GitHub Actions encrypted secrets only

## Rotation Playbook

1. Generate new certificate/profile pair.
2. Update all dependent secrets in repository settings.
3. Trigger validation run on a non-production tag.
4. Revoke old credentials after successful validation.

## Failure Signals

- Profile expired
- Certificate import failed
- Keychain unlock failed
- Export signing step failed
