import Testing

@testable import GaiaCore

struct LocalEnvironmentTests {
  @Test
  func mergedEnvironmentUsesOpenRouterKeychainFallbackWhenEnvIsMissing() {
    var environment = ["GAIA_ENV": "development"]
    LocalEnvironment.populateOpenRouterKeyIfNeeded(
      in: &environment,
      processEnvironment: ["USER": "test-user"],
      keychainSecretReader: { accountName, service in
        #expect(accountName == "test-user")
        #expect(service == LocalEnvironment.openRouterKeychainService)
        return "keychain-openrouter-token"
      }
    )

    #expect(environment[LocalEnvironment.openRouterAPIKeyKey] == "keychain-openrouter-token")
    #expect(environment[LocalEnvironment.openRouterLegacyAPIKeyKey] == nil)
  }

  @Test
  func mergedEnvironmentDoesNotOverrideExistingOpenRouterKey() {
    var environment = [LocalEnvironment.openRouterAPIKeyKey: "env-token"]
    LocalEnvironment.populateOpenRouterKeyIfNeeded(
      in: &environment,
      processEnvironment: ["USER": "test-user"],
      keychainSecretReader: { _, _ in
        Issue.record("keychain fallback should not run when env already has a token")
        return "unexpected"
      }
    )

    #expect(environment[LocalEnvironment.openRouterAPIKeyKey] == "env-token")
    #expect(environment[LocalEnvironment.openRouterLegacyAPIKeyKey] == nil)
  }

  @Test
  func normalizeOpenRouterEnvironmentPromotesLegacyKeyToCanonicalKey() {
    var environment = [LocalEnvironment.openRouterLegacyAPIKeyKey: "legacy-token"]

    LocalEnvironment.normalizeOpenRouterEnvironment(in: &environment)

    #expect(environment[LocalEnvironment.openRouterAPIKeyKey] == "legacy-token")
    #expect(environment[LocalEnvironment.openRouterLegacyAPIKeyKey] == nil)
  }

  @Test
  func openRouterDiagnosticReportsConfiguredTokenSafely() {
    let message = LocalEnvironment.openRouterDiagnosticMessage(
      appName: "GaiaCLI",
      environment: [
        "GAIA_OPENROUTER_DIAGNOSTICS": "true",
        LocalEnvironment.openRouterAPIKeyKey: "secret-token",
      ]
    )

    #expect(
      message
        == "[OpenRouter] aktiv fuer GaiaCLI (token source: GAIA_OPENROUTER_API_KEY, token length: 12)."
    )
  }

  @Test
  func openRouterDiagnosticReportsMissingToken() {
    let message = LocalEnvironment.openRouterDiagnosticMessage(
      appName: "GaiaCLI",
      environment: ["GAIA_OPENROUTER_DIAGNOSTICS": "true"]
    )

    #expect(
      message == "[OpenRouter] deaktiviert fuer GaiaCLI: kein GAIA_OPENROUTER_API_KEY gesetzt.")
  }

  @Test
  func openRouterDiagnosticNormalizesLegacyTokenToCanonicalSource() {
    let message = LocalEnvironment.openRouterDiagnosticMessage(
      appName: "GaiaCLI",
      environment: [
        "GAIA_OPENROUTER_DIAGNOSTICS": "true",
        LocalEnvironment.openRouterLegacyAPIKeyKey: "legacy-secret",
      ]
    )

    #expect(
      message
        == "[OpenRouter] aktiv fuer GaiaCLI (token source: GAIA_OPENROUTER_API_KEY, token length: 13)."
    )
  }

  @Test
  func openRouterDiagnosticStaysSilentWhenDisabled() {
    let message = LocalEnvironment.openRouterDiagnosticMessage(
      appName: "GaiaCLI",
      environment: [LocalEnvironment.openRouterAPIKeyKey: "secret-token"]
    )

    #expect(message == nil)
  }

  @Test
  func parsesPlainAssignment() {
    let entry = LocalEnvironment.parse(line: "GAIA_ROLLBAR_ACCESS_TOKEN=token-value")

    #expect(entry?.key == "GAIA_ROLLBAR_ACCESS_TOKEN")
    #expect(entry?.value == "token-value")
  }

  @Test
  func parsesExportedQuotedAssignment() {
    let entry = LocalEnvironment.parse(line: "export GAIA_ENV=\"development\"")

    #expect(entry?.key == "GAIA_ENV")
    #expect(entry?.value == "development")
  }

  @Test
  func ignoresCommentsAndBlankLines() {
    #expect(LocalEnvironment.parse(line: "   ") == nil)
    #expect(LocalEnvironment.parse(line: "# comment") == nil)
  }

  @Test
  func processEnvironmentOverridesFileValues() {
    let merged = ["GAIA_ROLLBAR_ACCESS_TOKEN": "file-token"].merging(
      ["ROLLBAR_ACCESS_TOKEN": "global-token", "GAIA_ROLLBAR_ACCESS_TOKEN": "process-token"]
    ) { _, processValue in processValue }

    #expect(merged["GAIA_ROLLBAR_ACCESS_TOKEN"] == "process-token")
    #expect(merged["ROLLBAR_ACCESS_TOKEN"] == "global-token")
  }

  @Test
  func dashboardCacheTTLUsesConfiguredValue() {
    let ttl = LocalEnvironment.dashboardCacheTTL(in: [LocalEnvironment.dashboardCacheTTLKey: "60"])

    #expect(ttl == 60)
  }

  @Test
  func dashboardCacheTTLFallsBackToDefaultForInvalidInput() {
    let ttl = LocalEnvironment.dashboardCacheTTL(in: [
      LocalEnvironment.dashboardCacheTTLKey: "invalid"
    ])

    #expect(ttl == LocalEnvironment.defaultDashboardCacheTTL)
  }

  @Test
  func dashboardSSEEndpointUsesEnvironmentOverride() {
    let endpoint = LocalEnvironment.dashboardStatusEventsEndpoint(
      in: [LocalEnvironment.dashboardStatusEventsEndpointKey: " /api/custom/events "]
    )

    #expect(endpoint == "/api/custom/events")
  }

  @Test
  func dashboardSSEEndpointAddsLeadingSlashForPathOverrides() {
    let endpoint = LocalEnvironment.dashboardStatusEventsEndpoint(
      in: [LocalEnvironment.dashboardStatusEventsEndpointKey: "api/custom/events"]
    )

    #expect(endpoint == "/api/custom/events")
  }

  @Test
  func dashboardSSEEndpointExtractsPathFromAbsoluteURL() {
    let endpoint = LocalEnvironment.dashboardStatusEventsEndpoint(
      in: [
        LocalEnvironment.dashboardStatusEventsEndpointKey:
          "https://aither.local/api/custom/events?token=abc"
      ]
    )

    #expect(endpoint == "/api/custom/events")
  }

  @Test
  func dashboardSSEEndpointFallsBackToDefaultForInvalidAbsoluteURL() {
    let endpoint = LocalEnvironment.dashboardStatusEventsEndpoint(
      in: [LocalEnvironment.dashboardStatusEventsEndpointKey: "https://[invalid-host"]
    )

    #expect(endpoint == LocalEnvironment.defaultDashboardStatusEventsEndpoint)
  }
}
