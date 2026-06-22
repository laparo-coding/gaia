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
}
