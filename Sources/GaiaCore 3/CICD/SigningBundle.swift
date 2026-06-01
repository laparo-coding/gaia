import Foundation

public struct SigningBundle: Equatable {
  public let teamId: String
  public let bundleId: String
  public let certificateRef: String
  public let provisioningProfileRef: String
  public let expiresAt: Date

  public init(
    teamId: String,
    bundleId: String,
    certificateRef: String,
    provisioningProfileRef: String,
    expiresAt: Date
  ) {
    self.teamId = teamId
    self.bundleId = bundleId
    self.certificateRef = certificateRef
    self.provisioningProfileRef = provisioningProfileRef
    self.expiresAt = expiresAt
  }

  public func validate(at date: Date = Date()) -> SigningBundleValidationResult {
    guard !teamId.isEmpty, !bundleId.isEmpty else {
      return .missingCoreIdentity
    }

    guard !certificateRef.isEmpty, !provisioningProfileRef.isEmpty else {
      return .missingSigningReferences
    }

    guard expiresAt > date else {
      return .expired
    }

    return .valid
  }
}

public enum SigningBundleValidationResult: Equatable {
  case valid
  case missingCoreIdentity
  case missingSigningReferences
  case expired
}
