import Foundation

public enum LocalEnvironment {
  public static let dashboardCacheTTLKey = "GAIA_DASHBOARD_CACHE_TTL_SECONDS"
  public static let dashboardStatusEventsEndpointKey = "GAIA_DASHBOARD_SSE_ENDPOINT"
  public static let defaultDashboardCacheTTL: TimeInterval = 45
  public static let defaultDashboardStatusEventsEndpoint = "/api/dashboard/status/events"

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
