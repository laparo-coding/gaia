# Quickstart: Authentication

## Goal

Validate Gaia's interactive authentication foundation and its service-to-service authentication against Hemera and Aither.

## Prerequisites

1. Configure Gaia with interactive auth settings for the chosen identity provider.
2. Provide server-side service credentials for both downstream targets:
   - a Hemera Bearer credential sourced from environment or a secrets manager
   - an Aither Bearer credential sourced from environment or a secrets manager
3. Ensure the local Swift toolchain can run `swift build`; use a full Xcode toolchain when executing `swift test`.

## Validation Scenarios

### Scenario 1: Interactive sign-in protects restricted content

1. Start Gaia in the local development workflow.
2. Navigate to a protected route.
3. Confirm Gaia redirects to or presents the sign-in flow.
4. Complete sign-in with valid credentials.
5. Verify Gaia restores the original destination or routes to the signed-in landing page.

### Scenario 2: Interactive auth fails safely

1. Attempt sign-in with invalid credentials or an unavailable provider.
2. Verify Gaia shows a clear failure state.
3. Confirm no sensitive provider or secret details are exposed to the user.

### Scenario 3: Hemera service auth uses cached X-API-Key credentials

1. Trigger a Gaia flow that needs Hemera data.
2. Verify Gaia loads or refreshes the Hemera service credential server-side.
3. Confirm Gaia sends its Hemera service credential as X-API-Key (not an interactive user session token).
4. Repeat the same Hemera call and verify the cached credential path uses X-API-Key while valid.

### Scenario 4: Aither control flow requires separate service auth

1. Trigger a Gaia flow that controls a protected Aither function.
2. Verify Gaia authenticates to Aither with its own server-side Bearer credential.
3. Confirm Hemera auth state is not reused as a substitute for Aither auth.

### Scenario 5: Retry on expiry happens once

1. Simulate an expired Hemera or Aither credential.
2. Observe a downstream `401` or `WWW-Authenticate` response.
3. Verify Gaia refreshes the affected credential once and retries the call one time.
4. If the refresh still fails, verify Gaia clears the invalid cache entry, logs the failure, and returns a safe degraded response.
