# Data Model: Authentication

## UserSession

- Purpose: Represents the interactive authenticated state for a Gaia user.
- Fields:
  - `sessionId`: String, unique session identifier
  - `subjectId`: String, authenticated user identifier
  - `role`: String, resolved authorization role
  - `status`: Enum (`unauthenticated`, `authenticating`, `authenticated`, `expired`, `signedOut`, `failed`)
  - `issuedAt`: Date
  - `expiresAt`: Date
  - `returnToPath`: String?
- Validation Rules:
  - `subjectId` is required when `status == authenticated`
  - `expiresAt` must be later than `issuedAt`
  - `returnToPath` must be a safe internal path when present
- State Transitions:
  - `unauthenticated -> authenticating -> authenticated`
  - `authenticated -> expired`
  - `authenticated -> signedOut`
  - `authenticating -> failed`

## AuthCredentials

- Purpose: Represents an interactive credential exchange or identity-provider response.
- Fields:
  - `provider`: Enum (`interactive`, `service`)
  - `tokenType`: Enum (`bearer`)
  - `audience`: Enum (`gaia`, `hemera`, `aither`)
  - `issuedAt`: Date?
  - `expiresAt`: Date?
  - `source`: Enum (`environment`, `secretsManager`, `identityProvider`)
- Validation Rules:
  - `tokenType` is always `bearer` for service flows in this feature
  - `audience` must match the downstream service being contacted

## AuthorizationRule

- Purpose: Encodes access boundaries for protected routes and controlled actions.
- Fields:
  - `resource`: String
  - `action`: String
  - `allowedRoles`: [String]
  - `requiresActiveSession`: Bool
  - `requiresServiceAudience`: Enum? (`hemera`, `aither`)
- Validation Rules:
  - `allowedRoles` must not be empty for protected resources
  - `requiresServiceAudience` is required for downstream-controlled operations

## ServiceCredential

- Purpose: Represents Gaia's server-side credential configuration for a downstream service.
- Fields:
  - `service`: Enum (`hemera`, `aither`)
  - `envPrimaryKey`: String
  - `envFallbackKey`: String?
  - `cacheKey`: String
  - `tokenType`: Enum (`bearer`)
  - `audience`: String
  - `refreshLeewaySeconds`: Int
- Validation Rules:
  - `service` must be unique per credential definition
  - `cacheKey` must be unique per service
  - `refreshLeewaySeconds` must be non-negative

## ServiceTokenCache

- Purpose: Tracks the cached token state for Hemera and Aither service calls.
- Fields:
  - `service`: Enum (`hemera`, `aither`)
  - `token`: String
  - `expiresAt`: Date
  - `lastRefreshAt`: Date
  - `retryConsumed`: Bool
- Validation Rules:
  - Cached entries must be evicted when expired or invalidated after failed refresh
  - `retryConsumed` resets for each new outbound request path
- State Transitions:
  - `missing -> loaded -> cached`
  - `cached -> refreshRequired -> cached`
  - `cached -> invalidated`
  - `refreshRequired -> failed`

## Relationships

- `UserSession` is evaluated against one or more `AuthorizationRule` entries.
- `ServiceCredential` defines how a `ServiceTokenCache` entry is populated for a given downstream target.
- Protected Hemera and Aither operations require both a valid `UserSession` context or explicit server authorization decision and a valid downstream `ServiceTokenCache` entry.
