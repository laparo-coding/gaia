import Testing

@testable import GaiaCore

struct RollbarBootstrapTests {
  @Test
  func prefersGaiaSpecificAccessToken() {
    let token = RollbarBootstrap.resolvedAccessToken(
      from: [
        "GAIA_ROLLBAR_ACCESS_TOKEN": "gaia-token",
        "ROLLBAR_ACCESS_TOKEN": "fallback-token",
      ])

    #expect(token == "gaia-token")
  }

  @Test
  func prefersGaiaSpecificAccessTokenConfiguration() {
    let configuration = RollbarBootstrap.resolvedAccessTokenConfiguration(
      from: [
        "GAIA_ROLLBAR_ACCESS_TOKEN": "gaia-token",
        "ROLLBAR_ACCESS_TOKEN": "fallback-token",
      ])

    #expect(
      configuration
        == .init(source: "GAIA_ROLLBAR_ACCESS_TOKEN", value: "gaia-token")
    )
  }

  @Test
  func fallsBackToSharedAccessToken() {
    let token = RollbarBootstrap.resolvedAccessToken(
      from: [
        "ROLLBAR_ACCESS_TOKEN": "fallback-token"
      ])

    #expect(token == "fallback-token")
  }

  @Test
  func ignoresEmptyAccessTokens() {
    let token = RollbarBootstrap.resolvedAccessToken(
      from: [
        "GAIA_ROLLBAR_ACCESS_TOKEN": "   ",
        "ROLLBAR_ACCESS_TOKEN": "",
      ])

    #expect(token == nil)
  }

  @Test
  func resolvesDevelopmentEnvironmentFromGaiaEnv() {
    let environment = RollbarBootstrap.resolvedRuntimeEnvironment(
      from: [
        "GAIA_ENV": "development"
      ])

    #expect(environment == .development)
    #expect(RollbarBootstrap.shouldSendStartupMessage(for: environment))
  }

  @Test
  func resolvesTestEnvironmentFromXCTestConfiguration() {
    let environment = RollbarBootstrap.resolvedRuntimeEnvironment(
      from: [
        "XCTestConfigurationFilePath": "/tmp/test.xctestconfiguration"
      ])

    #expect(environment == .test)
    #expect(RollbarBootstrap.shouldSendStartupMessage(for: environment))
  }

  @Test
  func suppressesStartupMessageInProduction() {
    let environment = RollbarBootstrap.resolvedRuntimeEnvironment(
      from: [
        "GAIA_ENV": "production"
      ])

    #expect(environment == .production)
    #expect(!RollbarBootstrap.shouldSendStartupMessage(for: environment))
  }

  @Test
  func buildsGaiaSpecificStartupMessage() {
    let message = RollbarBootstrap.startupMessage(
      appName: "GaiaCLI",
      environment: .development
    )

    #expect(message == "GaiaCLI Rollbar initialisiert (Environment: development).")
  }

  @Test
  func emitsDiagnosticsByDefaultInDevelopment() {
    let enabled = RollbarBootstrap.shouldEmitDiagnostics(
      for: .development,
      environment: [:]
    )

    #expect(enabled)
  }

  @Test
  func suppressesDiagnosticsByDefaultInProduction() {
    let enabled = RollbarBootstrap.shouldEmitDiagnostics(
      for: .production,
      environment: [:]
    )

    #expect(!enabled)
  }

  @Test
  func supportsDiagnosticOverride() {
    let enabled = RollbarBootstrap.shouldEmitDiagnostics(
      for: .production,
      environment: [
        "GAIA_ROLLBAR_DIAGNOSTICS": "true"
      ])

    #expect(enabled)
  }

  @Test
  func buildsMissingTokenDiagnosticMessage() {
    let message = RollbarBootstrap.missingTokenDiagnosticMessage(
      appName: "GaiaCLI",
      environment: .development
    )

    #expect(
      message
        == "[Rollbar] deaktiviert fuer GaiaCLI (environment: development): kein GAIA_ROLLBAR_ACCESS_TOKEN oder ROLLBAR_ACCESS_TOKEN gesetzt."
    )
  }

  @Test
  func buildsActiveDiagnosticMessage() {
    let message = RollbarBootstrap.activeDiagnosticMessage(
      appName: "GaiaCLI",
      environment: .test,
      drainInterval: 2.5,
      accessTokenConfiguration: .init(
        source: "GAIA_ROLLBAR_ACCESS_TOKEN",
        value: "gaia-token"
      )
    )

    #expect(
      message
        == "[Rollbar] aktiv fuer GaiaCLI (environment: test, drain: 2.5s, token source: GAIA_ROLLBAR_ACCESS_TOKEN, token length: 10)."
    )
  }

  @Test
  func usesDefaultDeliveryDrainInterval() {
    let interval = RollbarBootstrap.resolvedDeliveryDrainInterval(from: [:])

    #expect(interval == 1.0)
  }

  @Test
  func supportsConfiguredDeliveryDrainInterval() {
    let interval = RollbarBootstrap.resolvedDeliveryDrainInterval(
      from: [
        "GAIA_ROLLBAR_DELIVERY_WAIT_SECONDS": "2.5"
      ])

    #expect(interval == 2.5)
  }

  @Test
  func clampsNegativeDeliveryDrainInterval() {
    let interval = RollbarBootstrap.resolvedDeliveryDrainInterval(
      from: [
        "ROLLBAR_DELIVERY_WAIT_SECONDS": "-4"
      ])

    #expect(interval == 0)
  }
}
