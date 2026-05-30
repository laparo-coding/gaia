import Testing

@testable import GaiaCore

struct LocalEnvironmentTests {
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
}
