import Foundation

public enum LocalEnvironment {
  public static let dashboardCacheTTLKey = "GAIA_DASHBOARD_CACHE_TTL_SECONDS"
  public static let dashboardStatusEventsEndpointKey = "GAIA_DASHBOARD_SSE_ENDPOINT"
  /// Environment key for the active runtime environment (`development`, `test`, `production`).
  public static let runtimeEnvironmentKey = "GAIA_ENV"
  /// Environment key to override Docker runtime detection for local testing/scripts (`true`/`false`).
  public static let dockerRuntimeOverrideKey = "GAIA_DOCKER_RUNTIME"
  public static let defaultDashboardCacheTTL: TimeInterval = 45
  public static let defaultDashboardStatusEventsEndpoint = "/api/dashboard/status/events"

  /// Environment key for the Hemera service base URL (per-environment configurable, FR-009).
  public static let hemeraBaseURLKey = "GAIA_HEMERA_BASE_URL"
  /// Optional fallback Hemera base URL used in local-network / Docker hybrid setups.
  public static let hemeraFallbackBaseURLKey = "GAIA_HEMERA_FALLBACK_BASE_URL"
  /// Environment key for the Aither service base URL (per-environment configurable, FR-009).
  public static let aitherBaseURLKey = "GAIA_AITHER_BASE_URL"
  /// Optional fallback Aither base URL used in local-network / Docker hybrid setups.
  public static let aitherFallbackBaseURLKey = "GAIA_AITHER_FALLBACK_BASE_URL"
  /// Backwards-compatible Aither base URL key.
  public static let legacyAitherBaseURLKey = "AITHER_BASE_URL"

  /// Represents the resolved runtime environment for Gaia.
  ///
  /// - `development`: Local development (default, includes Docker).
  /// - `test`: Unit/integration test runs.
  /// - `production`: Production deployments.
  public enum RuntimeEnvironment: String, Sendable {
    case development
    case test
    case production
  }

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

  /// Resolves the active runtime environment from environment variables and Docker detection.
  ///
  /// Resolution order:
  /// 1. Docker → always `development`.
  /// 2. XCTest / `GAIA_TEST=1` → `test`.
  /// 3. Explicit `GAIA_ENV=production` → `production` (**only** this key may elevate to production).
  /// 4. `GAIA_ENV`, `ROLLBAR_ENVIRONMENT`, `ENVIRONMENT`, `NODE_ENV` → `development` or `test`.
  /// 5. Xcode Previews → `development`.
  /// 6. CI (`CI=true`) → `test`.
  /// 7. Fallback → `development`.
  ///
  /// Production **requires** an explicit `GAIA_ENV=production` assignment.
  /// Generic environment variables such as `ENVIRONMENT` or `NODE_ENV` can never
  /// implicitly elevate the runtime to production (Constitution VI).
  ///
  /// - Parameter environment: The merged environment dictionary.
  /// - Returns: The resolved `RuntimeEnvironment`.
  public static func runtimeEnvironment(in environment: [String: String]) -> RuntimeEnvironment {
    // 1. Docker is always treated as development in Gaia.
    if isRunningInDocker(in: environment) {
      return .development
    }

    // 2. Explicit test harness detection.
    if environment["XCTestConfigurationFilePath"] != nil || environment["GAIA_TEST"] == "1" {
      return .test
    }

    // 3. Only GAIA_ENV may explicitly opt into production.
    if let gaiaEnv = environment[runtimeEnvironmentKey],
       let resolved = parseRuntimeEnvironment(gaiaEnv, allowProduction: true)
    {
      return resolved
    }

    // 4. Generic env vars may only resolve to development or test — never production.
    if let generic = firstMatchingGenericRuntimeEnvironment(from: environment) {
      return generic
    }

    // 5. Xcode Previews → development.
    if environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
      return .development
    }

    // 6. CI defaults to test, not production.
    if environment["CI"] == "true" {
      return .test
    }

    // 7. Safe default.
    return .development
  }

  /// Attempts to parse a raw environment variable string into a `RuntimeEnvironment`.
  ///
  /// - Parameters:
  ///   - rawValue: The raw string from the environment dictionary.
  ///   - allowProduction: When `false`, `"prod"` / `"production"` values return
  ///     `nil` instead of `.production`. This prevents generic env vars like
  ///     `NODE_ENV=production` from implicitly elevating to production mode.
  /// - Returns: The resolved runtime environment, or `nil` if the value is empty,
  ///   unrecognisable, or production was requested but disallowed.
  private static func parseRuntimeEnvironment(
    _ rawValue: String,
    allowProduction: Bool
  ) -> RuntimeEnvironment? {
    let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !value.isEmpty else { return nil }

    switch value {
    case "prod", "production":
      return allowProduction ? .production : nil
    case "dev", "development", "local":
      return .development
    case "test", "testing":
      return .test
    default:
      return nil
    }
  }

  /// Scans generic (non-GAIA) environment variables for a runtime environment hint.
  ///
  /// Checked keys: `ROLLBAR_ENVIRONMENT`, `ENVIRONMENT`, `NODE_ENV`.
  /// Production values are **never** accepted — only `.development` or `.test`
  /// may be returned from generic sources.
  ///
  /// - Parameter environment: The merged environment dictionary.
  /// - Returns: The first matching non-production environment, or `nil` if none matched.
  private static func firstMatchingGenericRuntimeEnvironment(
    from environment: [String: String]
  ) -> RuntimeEnvironment? {
    for key in ["ROLLBAR_ENVIRONMENT", "ENVIRONMENT", "NODE_ENV"] as [String] {
      if let resolved = parseRuntimeEnvironment(environment[key] ?? "", allowProduction: false) {
        return resolved
      }
    }
    return nil
  }

  /// Detects whether the process is running inside a Docker container.
  ///
  /// Checks for `/.dockerenv` file and Docker/containerd/kubepods markers in `/proc/1/cgroup`.
  /// - Returns: `true` if running in Docker, `false` otherwise.
  public static func isRunningInDocker() -> Bool {
    if FileManager.default.fileExists(atPath: "/.dockerenv") {
      return true
    }

    do {
      let cgroup = try String(contentsOfFile: "/proc/1/cgroup", encoding: .utf8)
      return cgroup.contains("docker") || cgroup.contains("containerd") || cgroup.contains("kubepods")
    } catch {
      return false
    }
  }

  private static func isRunningInDocker(in environment: [String: String]) -> Bool {
    if let override = environment[dockerRuntimeOverrideKey]?
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased(),
      !override.isEmpty
    {
      return override == "1" || override == "true" || override == "yes" || override == "on"
    }

    return isRunningInDocker()
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

  /// Resolves the preferred service base URL with Docker-aware ordering and
  /// runtime-specific defaults.
  ///
  /// ## Precedence rules (highest to lowest priority)
  ///
  /// 1. **Explicitly configured URLs** (from `GAIA_*_BASE_URL`, legacy keys,
  ///    or `GAIA_*_FALLBACK_BASE_URL`) — always win over defaults.
  /// 2. **Synthesised defaults** — used only when no configured URL exists.
  ///
  /// Within each tier, candidates are sorted by network proximity:
  /// loopback → `host.docker.internal` → private network → public.
  ///
  /// Duplicate URLs are **deduplicated** (first occurrence wins) so that
  /// setting the same value under multiple keys never produces ambiguity.
  ///
  /// - Parameters:
  ///   - service: The downstream service whose base URL is requested.
  ///   - environment: The merged environment dictionary.
  ///   - runtimeEnvironment: Pre-resolved runtime environment; resolved from
  ///     `environment` when `nil`.
  /// - Returns: The highest-priority validated base URL.
  /// - Throws: `ConfigurationError` when no candidate is available (production
  ///   Aither) or all configured values are malformed.
  public static func preferredServiceBaseURL(
    _ service: DownstreamService,
    in environment: [String: String],
    runtimeEnvironment: RuntimeEnvironment? = nil
  ) throws -> URL {
    let resolvedRuntimeEnvironment = runtimeEnvironment ?? self.runtimeEnvironment(in: environment)
    let configuredCandidates = try configuredServiceBaseURLCandidates(service, in: environment)
    let defaults = defaultServiceBaseURLCandidates(service, runtimeEnvironment: resolvedRuntimeEnvironment)

    // Tier 1: configured URLs always take precedence over synthesised defaults.
    // Tier 2: defaults are used only when no configured candidate exists.
    let candidates: [URL]
    if !configuredCandidates.isEmpty {
      candidates = uniqued(configuredCandidates)
    } else {
      candidates = uniqued(defaults)
    }

    let orderedCandidates = candidates.sorted(by: { lhs, rhs in
      candidatePriority(
        lhs,
        service: service,
        runtimeEnvironment: resolvedRuntimeEnvironment,
        environment: environment
      ) < candidatePriority(
        rhs,
        service: service,
        runtimeEnvironment: resolvedRuntimeEnvironment,
        environment: environment
      )
    })

    guard let preferred = orderedCandidates.first
    else {
      let key = baseURLKey(for: service)
      throw ConfigurationError.missingServiceBaseURL(service: service, key: key)
    }

    return preferred
  }

  /// Removes duplicate URLs while preserving order of first appearance.
  ///
  /// Uses absolute-string comparison so that `http://127.0.0.1:3000` and
  /// `http://127.0.0.1:3000/` are treated as equivalent.
  private static func uniqued(_ urls: [URL]) -> [URL] {
    var seen: Set<String> = []
    return urls.compactMap { url in
      let key = url.absoluteString
          .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      return seen.insert(key).inserted ? url : nil
    }
  }

  static func baseURLKey(for service: DownstreamService) -> String {
    switch service {
    case .hemera:
      return hemeraBaseURLKey
    case .aither:
      return aitherBaseURLKey
    }
  }

  private static func configuredServiceBaseURLCandidates(
    _ service: DownstreamService,
    in environment: [String: String]
  ) throws -> [URL] {
    var keys = [baseURLKey(for: service)]
    if service == .aither {
      keys.append(legacyAitherBaseURLKey)
    }

    let fallbackKey = fallbackBaseURLKey(for: service)
    if let fallbackKey {
      keys.append(fallbackKey)
    }

    var urls: [URL] = []
    for key in keys {
      guard
        let rawValue = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
        !rawValue.isEmpty
      else {
        continue
      }

      guard
        let url = URL(string: rawValue),
        let scheme = url.scheme?.lowercased(),
        (scheme == "http" || scheme == "https"),
        url.host != nil
      else {
        throw ConfigurationError.invalidServiceBaseURL(service: service, key: key, value: rawValue)
      }

      urls.append(url)
    }

    return urls
  }

  private static func fallbackBaseURLKey(for service: DownstreamService) -> String? {
    switch service {
    case .hemera:
      return hemeraFallbackBaseURLKey
    case .aither:
      return aitherFallbackBaseURLKey
    }
  }

  private static func defaultServiceBaseURLCandidates(
    _ service: DownstreamService,
    runtimeEnvironment: RuntimeEnvironment
  ) -> [URL] {
    switch (service, runtimeEnvironment) {
    case (.hemera, .production):
      return [URL(string: "https://www.hemera.academy")!]
    case (.hemera, _):
      return localNetworkCandidates(port: 3000)
    // Aither requires explicit base URL configuration in production;
    // no safe default exists for a remote / containerised deployment.
    // Development and test may use the conventional local port.
    case (.aither, .production):
      return []
    case (.aither, _):
      return localNetworkCandidates(port: 3500)
    }
  }

  private static func localNetworkCandidates(port: Int) -> [URL] {
    let loopbackURL = URL(string: "http://127.0.0.1:\(port)")!
    let localhostURL = URL(string: "http://localhost:\(port)")!
    let dockerBridgeURL = URL(string: "http://host.docker.internal:\(port)")!
    return [loopbackURL, localhostURL, dockerBridgeURL]
  }

  private static func candidatePriority(
    _ url: URL,
    service: DownstreamService,
    runtimeEnvironment: RuntimeEnvironment,
    environment: [String: String]
  ) -> Int {
    let host = url.host?.lowercased() ?? ""
    let inDocker = isRunningInDocker(in: environment)

    if service == .hemera && runtimeEnvironment == .production {
      if host.contains("hemera.academy") {
        return 0
      }
      return localNetworkPriority(host: host, inDocker: inDocker) + 10
    }

    return localNetworkPriority(host: host, inDocker: inDocker)
  }

  private static func localNetworkPriority(host: String, inDocker: Bool) -> Int {
    if inDocker {
      if host == "host.docker.internal" {
        return 0
      }
      if isLoopbackHost(host) {
        return 1
      }
      if isPrivateNetworkHost(host) {
        return 2
      }
      return 3
    }

    if isLoopbackHost(host) {
      return 0
    }
    if host == "host.docker.internal" {
      return 1
    }
    if isPrivateNetworkHost(host) {
      return 2
    }

    return 3
  }

  private static func isLoopbackHost(_ host: String) -> Bool {
    host == "localhost" || host == "127.0.0.1" || host == "::1" || host == "[::1]"
  }

  private static func isPrivateNetworkHost(_ host: String) -> Bool {
    if host.hasSuffix(".local") {
      return true
    }

    let octets = host.split(separator: ".")
    guard octets.count == 4,
      let first = Int(octets[0]),
      let second = Int(octets[1])
    else {
      return false
    }

    if first == 10 || first == 127 {
      return true
    }
    if first == 172 && (16...31).contains(second) {
      return true
    }
    if first == 192 && second == 168 {
      return true
    }

    return false
  }

  private static func unique(_ values: [URL]) -> [URL] {
    var seen: Set<String> = []
    var result: [URL] = []

    for value in values {
      let key = value.absoluteString
      if seen.insert(key).inserted {
        result.append(value)
      }
    }

    return result
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
