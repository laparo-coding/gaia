#if canImport(SwiftUI)
  import SwiftUI
  #if canImport(GaiaCore)
    import GaiaCore
  #endif

  struct ParticipantOverviewCard: View {
    let participants: [DashboardParticipant]

    private final class AvatarRedirectBlocker: NSObject, URLSessionTaskDelegate {
      func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
      ) async -> URLRequest? {
        nil
      }
    }

    private let columns = [
      GridItem(.flexible(), spacing: DashboardDesignTokens.Spacing.md),
      GridItem(.flexible(), spacing: DashboardDesignTokens.Spacing.md),
    ]

    var body: some View {
      VStack(alignment: .leading, spacing: DashboardDesignTokens.Spacing.lg) {
        Text("Participants")
          .font(.headline)
          .foregroundStyle(DashboardDesignTokens.Colors.textPrimary)

        LazyVGrid(columns: columns, spacing: DashboardDesignTokens.Spacing.md) {
          ForEach(participants) { participant in
            HStack(spacing: DashboardDesignTokens.Spacing.sm) {
              participantAvatar(for: participant)

              Text(participant.displayName)
                .font(.subheadline)
                .lineLimit(1)

              Spacer(minLength: 0)
            }
            .padding(DashboardDesignTokens.Spacing.md)
            .background(DashboardDesignTokens.Colors.surfaceMuted)
            .clipShape(
              RoundedRectangle(
                cornerRadius: DashboardDesignTokens.CornerRadius.inner, style: .continuous))
          }
        }
      }
      .padding(DashboardDesignTokens.Spacing.xl)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(DashboardDesignTokens.Colors.surface)
      .clipShape(
        RoundedRectangle(cornerRadius: DashboardDesignTokens.CornerRadius.card, style: .continuous)
      )
      .overlay(
        RoundedRectangle(cornerRadius: DashboardDesignTokens.CornerRadius.card, style: .continuous)
          .stroke(Color.black.opacity(0.08), lineWidth: 1)
      )
    }

    private func initials(from name: String) -> String {
      let tokens = name.split(separator: " ")
      if tokens.count >= 2 {
        return "\(tokens[0].prefix(1))\(tokens[1].prefix(1))".uppercased()
      }
      return String(name.prefix(2)).uppercased()
    }

    // MARK: - Avatar (Aither-pattern: RemoteImage → fallback initials)

    /// Maximum number of avatar images retained in memory. When exceeded, the
    /// oldest entries (by insertion order) are evicted to bound memory usage.
    private static let avatarCacheLimit = 50
    /// Maximum accepted avatar payload size (5 MB). Larger responses are rejected
    /// to prevent memory exhaustion from oversized/malicious images.
    private static let avatarMaxByteCount = 5 * 1024 * 1024

    @State private var avatarImages: [String: Image] = [:]
    @State private var avatarImageOrder: [String] = []
    @State private var avatarLoadErrors: [String: Bool] = [:]
    @State private var avatarInFlight: Set<String> = []

    @ViewBuilder
    private func participantAvatar(for participant: DashboardParticipant) -> some View {
      if let cached = avatarImages[participant.id] {
        cached
          .resizable()
          .scaledToFill()
          .frame(width: 34, height: 34)
          .clipShape(Circle())
          .transition(.opacity.combined(with: .scale(scale: 1.05)))
      } else if let url = participant.avatarURL, let safeURL = AvatarURLPolicy.validated(url) {
        ZStack {
          avatarFallbackCircle(name: participant.displayName)

          if avatarLoadErrors[participant.id] == true {
            Text("⚠")
              .font(.caption2)
              .foregroundStyle(.red)
              .offset(y: -12)
          } else {
            ProgressView()
              .scaleEffect(0.5)
          }
        }
        .frame(width: 34, height: 34)
        .task {
          await loadAvatar(for: participant, from: safeURL)
        }
      } else {
        #if DEBUG
          if let url = participant.avatarURL {
            let _ = {
              print("[GaiaUI] Avatar URL rejected by allowlist policy: \(url)")
            }()
          }
        #endif
        avatarFallbackCircle(name: participant.displayName)
      }
    }

    // MARK: - Avatar fetch with validation, deduping, and bounded cache

    private func loadAvatar(for participant: DashboardParticipant, from url: URL) async {
      let participantID = participant.id

      let shouldFetch = markAvatarFetchStart(participantID)
      guard shouldFetch else { return }

      defer { Task { @MainActor in markAvatarFetchEnd(participantID) } }

      do {
        let data = try await fetchAvatarData(from: url)
        let image = try decodeAvatarImage(from: data)
        await MainActor.run { cacheAvatarImage(image, for: participantID) }
      } catch is CancellationError {
        // Ignore cancellation: row torn down during scroll/replace.
        return
      } catch {
        #if DEBUG
          print("[GaiaUI] Avatar load FAILED: \(error)")
        #endif
        await MainActor.run { avatarLoadErrors[participantID] = true }
      }
    }

    @MainActor
    private func markAvatarFetchStart(_ participantID: String) -> Bool {
      // Dedup atomically on MainActor: skip if already loaded or in-flight.
      if avatarImages[participantID] != nil || avatarInFlight.contains(participantID) {
        return false
      }
      avatarInFlight.insert(participantID)
      return true
    }

    @MainActor
    private func markAvatarFetchEnd(_ participantID: String) {
      avatarInFlight.remove(participantID)
    }

    private func fetchAvatarData(from url: URL) async throws -> Data {
      var request = URLRequest(url: url)
      request.httpMethod = "GET"
      request.timeoutInterval = 10

      let redirectBlocker = AvatarRedirectBlocker()
      let session = URLSession(
        configuration: .ephemeral,
        delegate: redirectBlocker,
        delegateQueue: nil
      )
      defer { session.finishTasksAndInvalidate() }

      // Disable redirects for avatar fetch path to avoid SSRF bypass via
      // unvalidated redirect targets.
      let (stream, response) = try await session.bytes(for: request)
      try validateAvatarResponse(response)

      var data = Data()
      data.reserveCapacity(min(256 * 1024, Self.avatarMaxByteCount))

      // Stream bytes and reject oversized payloads before full allocation.
      for try await byte in stream {
        data.append(byte)
        if data.count > Self.avatarMaxByteCount {
          throw AvatarError.payloadTooLarge(byteCount: data.count)
        }
      }

      return data
    }

    private func validateAvatarResponse(_ response: URLResponse) throws {
      // Response validation: HTTP 200 required.
      guard let httpResponse = response as? HTTPURLResponse,
        httpResponse.statusCode == 200
      else {
        throw AvatarError.invalidResponse
      }

      // Content-Type must be an image type.
      let contentType = (httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
      guard contentType.hasPrefix("image/") else {
        throw AvatarError.invalidContentType(contentType)
      }
    }

    private func decodeAvatarImage(from data: Data) throws -> Image {
      #if canImport(AppKit)
        guard let nsImage = NSImage(data: data) else {
          throw AvatarError.invalidData
        }
        return Image(nsImage: nsImage)
      #elseif canImport(UIKit)
        guard let uiImage = UIImage(data: data) else {
          throw AvatarError.invalidData
        }
        return Image(uiImage: uiImage)
      #else
        throw AvatarError.invalidData
      #endif
    }

    /// Inserts an avatar image into the bounded cache, evicting the oldest entry
    /// when the cache limit is exceeded (simple LRU by insertion order).
    private func cacheAvatarImage(_ image: Image, for participantID: String) {
      if avatarImages[participantID] == nil {
        avatarImageOrder.append(participantID)
      }
      avatarImages[participantID] = image

      // Evict oldest entries until within the bound.
      while avatarImageOrder.count > Self.avatarCacheLimit {
        let oldest = avatarImageOrder.removeFirst()
        avatarImages.removeValue(forKey: oldest)
        avatarLoadErrors.removeValue(forKey: oldest)
      }
    }

    private enum AvatarError: Error {
      case invalidData
      case invalidResponse
      case invalidContentType(String)
      case payloadTooLarge(byteCount: Int)
    }

    // MARK: - Avatar URL allowlisting (SSRF protection)

    /// Validates a participant avatar URL before any network fetch.
    ///
    /// Avatar URLs originate from Hemera API responses and are therefore
    /// untrusted. Without validation, a compromised or malicious response could
    /// direct the dashboard to fetch `file://`, loopback, private-network, or
    /// cloud-metadata endpoints (SSRF). This policy enforces:
    ///
    /// - Scheme MUST be `http` or `https` (blocks `file://`, `data:`, etc.).
    /// - Host MUST be present and non-empty.
    /// - In production: loopback, link-local, and RFC-1918/private hosts are
    ///   rejected. Cloud-metadata hosts (`169.254.169.254`,
    ///   `metadata.google.internal`) are always rejected.
    /// - In development/test: loopback and private hosts are permitted so local
    ///   avatar services remain usable; link-local and metadata hosts are still
    ///   blocked.
    ///
    /// Returns `nil` for any URL that fails validation; the caller falls back to
    /// the initials avatar (soft-fail, never a hard error).
    private enum AvatarURLPolicy {
      /// Cloud-metadata endpoints that must never be fetched, regardless of
      /// runtime environment.
      private static let blockedMetadataHosts: Set<String> = [
        "169.254.169.254",  // AWS / Azure / GCP IMDS
        "metadata.google.internal",  // GCP metadata server
        "metadata.azure.com",  // Azure metadata
        "fd00:ec2::254",  // AWS IMDS IPv6
      ]

      static func validated(_ url: URL) -> URL? {
        guard
          let scheme = url.scheme?.lowercased(),
          scheme == "http" || scheme == "https",
          let rawHost = url.host?.lowercased(),
          !rawHost.isEmpty
        else {
          return nil
        }

        let host = canonicalHost(rawHost)
        guard !host.isEmpty else {
          return nil
        }

        // Always block cloud-metadata endpoints.
        if isAlwaysBlockedHost(host) {
          return nil
        }

        // In production, additionally block loopback and private networks.
        if isProductionEnvironment(ProcessInfo.processInfo.environment)
          && isProductionBlockedHost(host)
        {
          return nil
        }

        return url
      }

      private static func isAlwaysBlockedHost(_ host: String) -> Bool {
        if blockedMetadataHosts.contains(host) {
          return true
        }
        if let mappedIPv4 = ipv4MappedAddress(from: host) {
          return mappedIPv4 == "169.254.169.254"
            || isPrivateIPv4(mappedIPv4)
            || isLinkLocalIPv4(mappedIPv4)
        }
        // Link-local addresses (169.254.x.x, fe80::) are always blocked.
        return isLinkLocalHost(host)
      }

      private static func isProductionBlockedHost(_ host: String) -> Bool {
        isLoopbackHost(host) || isPrivateNetworkHost(host)
      }

      private static func isLoopbackHost(_ host: String) -> Bool {
        host == "localhost" || host == "127.0.0.1" || host == "::1" || host == "[::1]"
      }

      private static func isLinkLocalHost(_ host: String) -> Bool {
        // IPv4 link-local: 169.254.0.0/16 (excluding the metadata host already checked).
        let octets = host.split(separator: ".")
        if octets.count == 4, let first = Int(octets[0]), let second = Int(octets[1]) {
          if first == 169 && second == 254 {
            return true
          }
        }
        // IPv6 link-local: fe80::/10
        if host.hasPrefix("fe80") || host.hasPrefix("[fe80") {
          return true
        }
        return false
      }

      private static func isPrivateNetworkHost(_ host: String) -> Bool {
        if host.hasSuffix(".local") {
          return true
        }

        if let mappedIPv4 = ipv4MappedAddress(from: host) {
          return isPrivateIPv4(mappedIPv4)
        }

        if isPrivateIPv6Literal(host) {
          return true
        }

        return isPrivateIPv4(host)
      }

      private static func isPrivateIPv6Literal(_ host: String) -> Bool {
        // IPv6 unique-local (fc00::/7) and site-local (fec0::/10) prefixes.
        // Only apply to actual IPv6 literals (colon-containing or bracketed) to
        // avoid matching normal DNS names like "fc.example.com".
        guard isIPv6Literal(host) else {
          return false
        }
        let lower = host.lowercased()
        return lower.hasPrefix("fc") || lower.hasPrefix("fd") || lower.hasPrefix("fec0")
      }

      private static func canonicalHost(_ host: String) -> String {
        var canonical = host
        if canonical.hasPrefix("[") && canonical.hasSuffix("]") {
          canonical = String(canonical.dropFirst().dropLast())
        }
        // Strip trailing root dot (e.g. "metadata.google.internal.").
        while canonical.hasSuffix(".") {
          canonical.removeLast()
        }
        return canonical
      }

      private static func normalizedHost(_ host: String) -> String {
        canonicalHost(host)
      }

      private static func ipv4MappedAddress(from host: String) -> String? {
        let lowercased = normalizedHost(host).lowercased()
        guard lowercased.hasPrefix("::ffff:") else { return nil }
        let mapped = String(lowercased.dropFirst("::ffff:".count))
        let octets = mapped.split(separator: ".")
        guard octets.count == 4 else { return nil }
        guard octets.allSatisfy({ Int($0).map { (0...255).contains($0) } == true }) else {
          return nil
        }
        return mapped
      }

      private static func isLinkLocalIPv4(_ host: String) -> Bool {
        let octets = host.split(separator: ".")
        guard octets.count == 4,
          let first = Int(octets[0]),
          let second = Int(octets[1])
        else {
          return false
        }
        return first == 169 && second == 254
      }

      private static func isPrivateIPv4(_ host: String) -> Bool {
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

      private static func isProductionEnvironment(_ environment: [String: String]) -> Bool {
        let value = environment["GAIA_ENV"]?.trimmingCharacters(in: .whitespacesAndNewlines)
          .lowercased()
        // Fail closed: nil/unknown → production (blocks loopback/private).
        // Only explicit dev/test-style values opt out.
        switch value {
        case nil, "":
          return true
        case "dev", "development", "local", "test", "testing":
          return false
        default:
          return true
        }
      }

      private static func isIPv6Literal(_ host: String) -> Bool {
        host.contains(":") || (host.hasPrefix("[") && host.hasSuffix("]"))
      }
    }

    private func avatarFallbackCircle(name: String) -> some View {
      Circle()
        .fill(DashboardDesignTokens.Colors.accent.opacity(0.15))
        .frame(width: 34, height: 34)
        .overlay(
          Text(initials(from: name))
            .font(.caption.weight(.bold))
            .foregroundStyle(DashboardDesignTokens.Colors.accent)
        )
    }
  }
#endif
