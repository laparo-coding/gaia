# Feature Specification: Authentication

**Feature Branch**: `005-authentication`  
**Created**: 2026-05-30  
**Status**: Parked  
**Input**: User description: "Define the authentication foundation for Gaia, including the same service authentication procedure that Aither uses for Hemera API access."

## Clarifications

### Session 2026-05-30

- Q: Which service-to-service authentication method should Gaia use for Hemera and Aither? → A: Gaia uses dedicated server-side service credentials, but the downstream wire format follows the target service contract: `X-API-Key` for Hemera service APIs and `Authorization: Bearer` for protected Aither sync operations, with per-service token caching and one retry on expiry.

## User Scenarios & Testing

### Primary User Story

As a Gaia user and system client, I want a clear and secure authentication flow,
so interactive users can access protected areas safely and Gaia can
authenticate against Hemera and Aither before retrieving data from Hemera or
triggering protected Aither functionality.

### Acceptance Scenarios

1. **Given** a user reaches a protected area without an active session,
	**When** they access the authentication entry point, **Then** they are
	prompted to sign in before protected content is shown.
2. **Given** a user provides valid credentials,
	**When** the authentication flow succeeds, **Then** the application grants
	access and routes the user to the intended destination.
3. **Given** a user provides invalid credentials or the authentication system
	is unavailable, **When** the request fails, **Then** the application shows a
	clear error state and preserves a safe recovery path.
4. **Given** Gaia needs to call Hemera or protected Aither capabilities,
	**When** it performs a service-to-service request, **Then** it authenticates
	with the target-specific downstream contract before the request is sent:
	`X-API-Key` for Hemera service APIs and `Authorization: Bearer` for the
	protected Aither sync endpoint.

### Edge Cases

- What happens when a user session expires while they are on a protected route?
- What happens when the authentication provider is temporarily unavailable?
- What happens when a signed-in user lacks permission for a requested area?
- What happens when Gaia can authenticate to Hemera but not to Aither, or the
	reverse?
- What happens when a cached service token is expired and a downstream service
	responds with `401` or `WWW-Authenticate`?

## Requirements

### Functional Requirements

- **FR-001**: The application MUST provide an authentication entry point for
	users who need to access protected functionality.
- **FR-002**: Protected routes MUST deny access when no valid session is
	present.
- **FR-003**: Successful authentication MUST restore the intended destination
	or route the user to a defined signed-in landing area.
- **FR-004**: Failed authentication attempts MUST surface a clear error state
	without exposing sensitive system details.
- **FR-005**: The authentication flow MUST define how session expiry and
	sign-out return the user to a safe unauthenticated state.
- **FR-006**: The feature MUST define an authorization boundary so users without
	required permissions cannot access restricted areas.
- **FR-008**: Gaia MUST use the same service-to-service authentication
	procedure that Aither uses for Hemera API access when Gaia authenticates to
	Hemera, and MUST use a dedicated service-to-service credential instead of an
	interactive user session when Gaia authenticates to Aither.
- **FR-009**: Service-to-service authentication MUST use a server-side service
	credential sourced from environment variables or a secrets manager, not an
	interactive user session token.
- **FR-008a**: Gaia MUST send its Hemera service credential as `X-API-Key` so
	it matches Hemera's service API contract.
- **FR-008b**: Gaia MUST send its Aither service credential as
	`Authorization: Bearer <token>` when triggering protected Aither sync
	operations.
- **FR-010**: Gaia MUST authenticate separately against Hemera and Aither
	before it retrieves data from Hemera or triggers protected Aither
	functionalities.
- **FR-011**: Service credentials MUST support short-lived token usage with
	token caching and proactive refresh or retry-on-expiry behavior.
- **FR-012**: If Hemera or Aither responds with an authentication expiry signal
	(such as `401` or `WWW-Authenticate`), Gaia MUST refresh the affected
	credential once and retry the failed request one time.
- **FR-013**: If service authentication refresh or retry fails, Gaia MUST clear
	invalid cached credentials, log the failure, and fail safely without exposing
	secrets.

### Key Entities

- **UserSession**: Represents the authenticated state of a user, including
	identity, lifetime, and session validity.
- **AuthCredentials**: Represents the credential payload or provider response
	used to establish a session.
- **AuthorizationRule**: Represents the access rules that control which users
	may enter protected application areas.
- **ServiceCredential**: Represents the server-side credential Gaia uses to authenticate to Hemera or Aither for service-to-service API calls, including
	which downstream header contract the credential must satisfy.
- **ServiceTokenCache**: Represents the cached token state and expiry metadata
	used to reuse and refresh short-lived service credentials safely.

## Review & Acceptance Checklist

### Content Quality

- [x] No implementation details that are irrelevant to user value
- [x] Focused on secure user access and clear recovery behavior
- [x] Written for repo stakeholders and maintainers
- [x] All mandatory sections completed

### Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified
- [x] Security, observability, and failure-state expectations are captured when relevant

## Execution Status

- [x] User description parsed
- [x] Key concepts extracted
- [x] Ambiguities marked
- [x] User scenarios defined
- [x] Requirements generated
- [x] Entities identified
- [x] Review checklist passed