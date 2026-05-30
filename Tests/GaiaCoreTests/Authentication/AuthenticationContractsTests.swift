import Foundation
import Testing

@testable import GaiaCore

struct AuthenticationContractsTests {
  @Test
  func contractDefinesInteractiveSessionEndpoints() throws {
    let contract = try String(contentsOf: AuthTestSupport.contractURL(), encoding: .utf8)

    #expect(contract.contains("/api/auth/session:"))
    #expect(contract.contains("/api/auth/sign-in:"))
  }

  @Test
  func contractDefinesServiceAuthorizationEndpointsAndSchemas() throws {
    let contract = try String(contentsOf: AuthTestSupport.contractURL(), encoding: .utf8)

    #expect(contract.contains("/api/auth/service/hemera/authorize:"))
    #expect(contract.contains("/api/auth/service/aither/authorize:"))
    #expect(contract.contains("SessionState:"))
    #expect(contract.contains("ServiceAuthorizationResponse:"))
  }
}
