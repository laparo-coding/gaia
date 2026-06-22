import Foundation

public enum LocalEnvironment {
  public static let dashboardCacheTTLKey = "GAIA_DASHBOARD_CACHE_TTL_SECONDS"
  public static let dashboardStatusEventsEndpointKey = "GAIA_DASHBOARD_SSE_ENDPOINT"
  public static let defaultDashboardCacheTTL: TimeInterval = 45
  public static let defaultDashboardStatusEventsEndpoint = "/api/dashboard/status/events"

  /// Environment key for the Hemera service base URL (per-environment configurable, FR-009).
  public static let hemeraBaseURLKey = "GAIA_HEMERA_BASE_URL"
  /// Environment key for the Aither service base URL (per-environment configurable, FR-009).
  public static let aitherBaseURLKey = "GAIA_AITHER_BASE_URL"

  /// Structured configuration failure for required environment values.
  ///
  /// Missing or invalid required configuration MUST fail explicitly rather than
  /// silently serving placeholder data (Constitution VI; FR-009/FR-010).
  public enum ConfigurationError: Error, Equatable, Sendable {
    /// The required environment key was absent or blank.
    case missingServiceBaseURL(service: DownstreamService, key: String)
    /// The configured value could not be parsed into a URL with a scheme.
    case invalidServiceBaseURL(service: DownstreamService, key: String, value: String)
  }

  /// Resolves the configured base URL for a downstream service, failing
  /// explicitly when the value is missing or malformed.
  ///
  /// - Parameters:
  ///   - service: The downstream service whose base URL is requested.
  ///   - environment: The merged environment dictionary.
  /// - Returns: A validated absolute `URL` carrying a scheme.
  /// - Throws: `ConfigurationError` when the value is missing or invalid.
  public static func serviceBaseURL(
    _ service: DownstreamService,
    in environment: [String: String]
  ) throws -> URL {
    let key = baseURLKey(for: service)

    guard
      let rawValue = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
      !rawValue.isEmpty
    else {
      throw ConfigurationError.missingServiceBaseURL(service: service, key: key)
    }

    guard
      let url = URL(string: rawValue),
      let scheme = url.scheme?.lowercased(),
      scheme == "http" || scheme == "https",
      url.host != nil
    else {
      throw ConfigurationError.invalidServiceBaseURL(service: service, key: key, value: rawValue)
    }

    return url
  }

  static func baseURLKey(for service: DownstreamService) -> String {
    switch service {
    case .hemera:
      return hemeraBaseURLKey
    case .aither:
      return aitherBaseURLKey
    }
  }

  public static func mergedWithProcessEnvironment(
    currentDirectoryPath: String,
    processEnvironment: [String: String]
  ) -> [String: String] {
    guard let repositoryRoot = resolveRepositoryRoot(from: currentDirectoryPath) else {
      return processEnvironment
    }

    let fileEnvironment = loadEnvironmentFile(
      at: repositoryRoot.appendingPathComponent(".env.local", isDirectory: false)
    )

    return fileEnvironment.merging(processEnvironment) { _, processValue in processValue }
  }

  public static func dashboardCacheTTL(in environment: [String: String]) -> TimeInterval {
    guard
      let rawValue = environment[dashboardCacheTTLKey],
      let parsedValue = Double(rawValue),
      parsedValue > 0
    else {
      return defaultDashboardCacheTTL
    }

    return parsedValue
  }

  public static func dashboardStatusEventsEndpoint(in environment: [String: String]) -> String {
    guard
      let endpoint = environment[dashboardStatusEventsEndpointKey]?.trimmingCharacters(
        in: .whitespacesAndNewlines), !endpoint.isEmpty
    else {
      return defaultDashboardStatusEventsEndpoint
    }

    guard let normalizedEndpoint = normalizeDashboardStatusEndpoint(endpoint) else {
      return defaultDashboardStatusEventsEndpoint
    }

    return normalizedEndpoint
  }

  static func normalizeDashboardStatusEndpoint(_ endpoint: String) -> String? {
    if endpoint.contains("://") {
      guard let components = URLComponents(string: endpoint),
        let scheme = components.scheme,
        !scheme.isEmpty
      else {
        return nil
      }

      let path = components.path.trimmingCharacters(in: .whitespacesAndNewlines)
      if path.isEmpty || path == "/" {
        return defaultDashboardStatusEventsEndpoint
      }

      return path.hasPrefix("/") ? path : "/" + path
    }

    let trimmedPath = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedPath.isEmpty else {
      return nil
    }

    return trimmedPath.hasPrefix("/") ? trimmedPath : "/" + trimmedPath
  }

  static func resolveRepositoryRoot(from currentDirectoryPath: String) -> URL? {
    var candidate = URL(fileURLWithPath: currentDirectoryPath, isDirectory: true)

    while true {
      let packageManifest = candidate.appendingPathComponent("Package.swift", isDirectory: false)
      if FileManager.default.fileExists(atPath: packageManifest.path) {
        return candidate
      }

      let parent = candidate.deletingLastPathComponent()
      if parent.path == candidate.path {
        return nil
      }

      candidate = parent
    }
  }

  static func loadEnvironmentFile(at fileURL: URL) -> [String: String] {
    guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
      return [:]
    }

    var environment: [String: String] = [:]

    for line in content.split(whereSeparator: \.isNewline) {
      guard let entry = parse(line: String(line)) else {
        continue
      }

      environment[entry.key] = entry.value
    }

    return environment
  }

  static func parse(line: String) -> (key: String, value: String)? {
    let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedLine.isEmpty, !trimmedLine.hasPrefix("#") else {
      return nil
    }

    let normalizedLine: String
    if trimmedLine.hasPrefix("export ") {
      normalizedLine = String(trimmedLine.dropFirst("export ".count))
    } else {
      normalizedLine = trimmedLine
    }

    guard let separatorIndex = normalizedLine.firstIndex(of: "=") else {
      return nil
    }

    let rawKey = normalizedLine[..<separatorIndex].trimmingCharacters(in: .whitespacesAndNewlines)
    guard !rawKey.isEmpty else {
      return nil
    }

    let rawValue = normalizedLine[normalizedLine.index(after: separatorIndex)...]
      .trimmingCharacters(in: .whitespacesAndNewlines)

    return (key: rawKey, value: unquote(rawValue))
  }

  static func unquote(_ value: String) -> String {
    guard value.count >= 2 else {
      return value
    }

    if (value.hasPrefix("\"") && value.hasSuffix("\""))
      || (value.hasPrefix("'") && value.hasSuffix("'"))
    {
      return String(value.dropFirst().dropLast())
    }

    return value
  }
}
