import Testing

@testable import GaiaCore

struct AuthorizationRuleTests {
  @Test
  func serviceCredentialsRequireDownstreamAudience() throws {
    let credentials = try AuthCredentials(
      provider: .service,
      tokenType: .bearer,
      audience: .hemera,
      issuedAt: AuthTestSupport.issuedAt,
      expiresAt: AuthTestSupport.expiresAt,
      source: .environment
    )

    #expect(credentials.audience == .hemera)

    #expect(throws: AuthenticationError.self) {
      _ = try AuthCredentials(
        provider: .service,
        tokenType: .bearer,
        audience: .gaia,
        issuedAt: AuthTestSupport.issuedAt,
        expiresAt: AuthTestSupport.expiresAt,
        source: .environment
      )
    }
  }

  @Test
  func protectedRulesRequireAllowedRoles() {
    #expect(throws: AuthenticationError.self) {
      _ = try AuthorizationRule(
        resource: AuthTestSupport.protectedResource,
        action: "read",
        allowedRoles: [],
        requiresActiveSession: true,
        requiresServiceAudience: nil
      )
    }
  }

  @Test
  func downstreamRulesRetainRequiredServiceAudience() throws {
    let rule = try AuthorizationRule(
      resource: "service/hemera",
      action: AuthTestSupport.operation,
      allowedRoles: [AuthTestSupport.role],
      requiresActiveSession: true,
      requiresServiceAudience: .hemera
    )

    #expect(rule.requiresServiceAudience == .hemera)
  }
}
