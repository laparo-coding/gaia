import Foundation

enum AuthTestSupport {
  static let issuedAt = Date(timeIntervalSince1970: 1_717_000_000)
  static let expiresAt = Date(timeIntervalSince1970: 1_717_003_600)
  static let refreshedAt = Date(timeIntervalSince1970: 1_717_001_800)

  static let validReturnPath = "/dashboard"
  static let invalidReturnPath = "https://example.com/phishing"
  static let sessionId = "session-123"
  static let subjectId = "user-123"
  static let role = "admin"
  static let requestId = "req-123"
  static let operation = "service:sync-courses"
  static let protectedResource = "/admin/courses"

  static let hemeraAudience = "hemera"
  static let aitherAudience = "aither"
  static let hemeraCacheKey = "service.hemera"
  static let aitherCacheKey = "service.aither"
  static let hemeraEnvKey = "HEMERA_SERVICE_TOKEN"
  static let aitherEnvKey = "AITHER_SERVICE_TOKEN"

  static func expiry(after issuedAt: Date, seconds: TimeInterval = 3_600) -> Date {
    issuedAt.addingTimeInterval(seconds)
  }

  static func contractURL(filePath: String = #filePath) -> URL {
    // contractURL assumes this test file is four directory levels below repo root.
    // The four deletingLastPathComponent() calls walk from Tests/.../Authentication to root.
    URL(fileURLWithPath: filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("specs/005-authentication/contracts/openapi.yaml")
  }
}
