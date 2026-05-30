import Testing

@testable import GaiaCore

struct InteractiveFailureScenarioTests {
  @Test
  func failedSignInProducesSafeRecoveryState() async throws {
    let manager = AuthenticationSessionManager()
    let telemetry = AuthenticationTelemetry()

    _ = try await manager.startSignIn(returnToPath: AuthTestSupport.validReturnPath)
    let failed = await manager.failSignIn()
    let message = await telemetry.safeUserMessage(
      for: .unsafeFailure(reason: "identityProvider=down secret=abc123")
    )

    #expect(failed.status == .failed)
    #expect(failed.subjectId == nil)
    #expect(message.contains("Authentication failed"))
    #expect(message.contains("abc123") == false)
  }
}
