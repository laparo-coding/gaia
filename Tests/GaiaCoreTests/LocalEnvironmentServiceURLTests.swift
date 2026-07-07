import Foundation
import Testing

@testable import GaiaCore

struct LocalEnvironmentServiceURLTests {
  @Test
  func resolvesHemeraBaseURLFromEnvironment() throws {
    let url = try LocalEnvironment.serviceBaseURL(
      .hemera,
      in: [LocalEnvironment.hemeraBaseURLKey: "https://hemera.dev.example.com"]
    )

    #expect(url == URL(string: "https://hemera.dev.example.com"))
  }

  @Test
  func resolvesAitherBaseURLFromEnvironment() throws {
    let url = try LocalEnvironment.serviceBaseURL(
      .aither,
      in: [LocalEnvironment.aitherBaseURLKey: "https://aither.dev.example.com"]
    )

    #expect(url == URL(string: "https://aither.dev.example.com"))
  }

  @Test
  func throwsExplicitErrorWhenHemeraBaseURLMissing() {
    #expect(throws: LocalEnvironment.ConfigurationError.self) {
      _ = try LocalEnvironment.serviceBaseURL(.hemera, in: [:])
    }
  }

  @Test
  func throwsExplicitErrorWhenBaseURLIsBlank() {
    #expect(throws: LocalEnvironment.ConfigurationError.self) {
      _ = try LocalEnvironment.serviceBaseURL(
        .aither, in: [LocalEnvironment.aitherBaseURLKey: "   "])
    }
  }

  @Test
  func throwsExplicitErrorWhenBaseURLHasNoScheme() {
    #expect(throws: LocalEnvironment.ConfigurationError.self) {
      _ = try LocalEnvironment.serviceBaseURL(
        .hemera, in: [LocalEnvironment.hemeraBaseURLKey: "localhost:3500"])
    }
  }

  @Test
  func preferredHemeraUsesLocalNetworkInDevelopment() throws {
    let url = try LocalEnvironment.preferredServiceBaseURL(
      .hemera,
      in: [
        LocalEnvironment.runtimeEnvironmentKey: "development",
        LocalEnvironment.dockerRuntimeOverrideKey: "false",
      ]
    )

    #expect(url == URL(string: "http://127.0.0.1:3000"))
  }

  @Test
  func preferredAitherUsesDockerBridgeInDockerDevelopment() throws {
    let url = try LocalEnvironment.preferredServiceBaseURL(
      .aither,
      in: [
        LocalEnvironment.runtimeEnvironmentKey: "development",
        LocalEnvironment.dockerRuntimeOverrideKey: "true",
      ]
    )

    #expect(url == URL(string: "http://host.docker.internal:3500"))
  }

  @Test
  func preferredHemeraUsesAcademyInProduction() throws {
    let url = try LocalEnvironment.preferredServiceBaseURL(
      .hemera,
      in: [
        LocalEnvironment.runtimeEnvironmentKey: "production",
        LocalEnvironment.dockerRuntimeOverrideKey: "false",
      ]
    )

    #expect(url == URL(string: "https://www.hemera.academy"))
  }

  @Test
  func preferredAitherRequiresExplicitConfigInProduction() {
    // After removing the localhost default for Aither in production,
    // resolving without GAIA_AITHER_BASE_URL must fail explicitly.
    #expect(throws: LocalEnvironment.ConfigurationError.self) {
      _ = try LocalEnvironment.preferredServiceBaseURL(
        .aither,
        in: [
          LocalEnvironment.runtimeEnvironmentKey: "production",
          LocalEnvironment.dockerRuntimeOverrideKey: "false",
        ]
      )
    }
  }

  @Test
  func preferredAitherAcceptsExplicitConfigInProduction() throws {
    let url = try LocalEnvironment.preferredServiceBaseURL(
      .aither,
      in: [
        LocalEnvironment.runtimeEnvironmentKey: "production",
        LocalEnvironment.dockerRuntimeOverrideKey: "false",
        LocalEnvironment.aitherBaseURLKey: "http://aither.prod.example.com:4000",
      ]
    )

    #expect(url == URL(string: "http://aither.prod.example.com:4000"))
  }

  @Test
  func preferredHemeraRespectsConfiguredBaseURLOverDefaults() throws {
    let url = try LocalEnvironment.preferredServiceBaseURL(
      .hemera,
      in: [
        LocalEnvironment.runtimeEnvironmentKey: "development",
        LocalEnvironment.dockerRuntimeOverrideKey: "false",
        LocalEnvironment.hemeraBaseURLKey: "https://hemera.custom.example.com",
      ]
    )

    #expect(url == URL(string: "https://hemera.custom.example.com"))
  }

  @Test
  func preferredAitherRespectsConfiguredBaseURLOverDefaults() throws {
    let url = try LocalEnvironment.preferredServiceBaseURL(
      .aither,
      in: [
        LocalEnvironment.runtimeEnvironmentKey: "development",
        LocalEnvironment.dockerRuntimeOverrideKey: "false",
        LocalEnvironment.aitherBaseURLKey: "https://aither.custom.example.com",
      ]
    )

    #expect(url == URL(string: "https://aither.custom.example.com"))
  }

  @Test
  func preferredHemeraHonorsFallbackKeyWhenPrimaryAbsent() throws {
    let url = try LocalEnvironment.preferredServiceBaseURL(
      .hemera,
      in: [
        LocalEnvironment.runtimeEnvironmentKey: "development",
        LocalEnvironment.dockerRuntimeOverrideKey: "false",
        LocalEnvironment.hemeraFallbackBaseURLKey: "https://hemera.fallback.example.com",
      ]
    )

    #expect(url == URL(string: "https://hemera.fallback.example.com"))
  }

  @Test
  func preferredAitherHonorsFallbackKeyWhenPrimaryAbsent() throws {
    let url = try LocalEnvironment.preferredServiceBaseURL(
      .aither,
      in: [
        LocalEnvironment.runtimeEnvironmentKey: "development",
        LocalEnvironment.dockerRuntimeOverrideKey: "false",
        LocalEnvironment.aitherFallbackBaseURLKey: "https://aither.fallback.example.com",
      ]
    )

    #expect(url == URL(string: "https://aither.fallback.example.com"))
  }

  @Test
  func preferredAitherHonorsLegacyBaseURLKey() throws {
    let url = try LocalEnvironment.preferredServiceBaseURL(
      .aither,
      in: [
        LocalEnvironment.runtimeEnvironmentKey: "development",
        LocalEnvironment.dockerRuntimeOverrideKey: "false",
        LocalEnvironment.legacyAitherBaseURLKey: "https://aither.legacy.example.com",
      ]
    )

    #expect(url == URL(string: "https://aither.legacy.example.com"))
  }

  @Test
  func preferredHemeraConfiguredOverridesProductionDefault() throws {
    let url = try LocalEnvironment.preferredServiceBaseURL(
      .hemera,
      in: [
        LocalEnvironment.runtimeEnvironmentKey: "production",
        LocalEnvironment.dockerRuntimeOverrideKey: "false",
        LocalEnvironment.hemeraBaseURLKey: "https://hemera.staging.example.com",
      ]
    )

    #expect(url == URL(string: "https://hemera.staging.example.com"))
  }

  // MARK: - Deduplication

  @Test func deduplicatesIdenticalURLsFromMultipleEnvKeys() throws {
    // When primary, fallback, and legacy keys all resolve to the same URL,
    // the result must be that URL (not an array of duplicates).
    let url = try LocalEnvironment.preferredServiceBaseURL(
      .aither,
      in: [
        LocalEnvironment.runtimeEnvironmentKey: "development",
        LocalEnvironment.dockerRuntimeOverrideKey: "false",
        LocalEnvironment.aitherBaseURLKey: "http://127.0.0.1:3500",
        LocalEnvironment.aitherFallbackBaseURLKey: "http://127.0.0.1:3500",
        LocalEnvironment.legacyAitherBaseURLKey: "http://127.0.0.1:3500",
      ]
    )

    #expect(url == URL(string: "http://127.0.0.1:3500"))
  }

  @Test func primaryKeyWinsOverDuplicateFallbackWithSameValue() throws {
    // Even when primary and fallback point to the same host, primary should
    // appear first and win after dedup + sort.
    let url = try LocalEnvironment.preferredServiceBaseURL(
      .hemera,
      in: [
        LocalEnvironment.runtimeEnvironmentKey: "development",
        LocalEnvironment.dockerRuntimeOverrideKey: "false",
        LocalEnvironment.hemeraBaseURLKey: "http://localhost:3000",
        LocalEnvironment.hemeraFallbackBaseURLKey: "http://localhost:3000",
      ]
    )

    #expect(url == URL(string: "http://localhost:3000"))
  }

  @Test func trailingSlashURLsAreDeduplicatedAsEquivalent() throws {
    // http://127.0.0.1:3000 and http://127.0.0.1:3000/ should be treated
    // as the same candidate.
    let url = try LocalEnvironment.preferredServiceBaseURL(
      .hemera,
      in: [
        LocalEnvironment.runtimeEnvironmentKey: "development",
        LocalEnvironment.dockerRuntimeOverrideKey: "false",
        LocalEnvironment.hemeraBaseURLKey: "http://127.0.0.1:3000/",
        LocalEnvironment.hemeraFallbackBaseURLKey: "http://127.0.0.1:3000",
      ]
    )

    #expect(url == URL(string: "http://127.0.0.1:3000/"))
  }
}
