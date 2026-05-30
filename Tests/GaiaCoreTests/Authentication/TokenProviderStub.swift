@testable import GaiaCore

actor TokenProviderStub {
  private var tokens: [LoadedServiceToken]
  private var callCount = 0

  init(tokens: [LoadedServiceToken]) {
    self.tokens = tokens
  }

  func load(_: ServiceCredential) throws -> LoadedServiceToken {
    callCount += 1

    guard !tokens.isEmpty else {
      throw AuthenticationError.serviceAuthorizationFailed(service: .aither)
    }

    return tokens.removeFirst()
  }

  func currentCallCount() -> Int {
    callCount
  }
}
