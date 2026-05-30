public struct RollbackCandidate: Equatable {
  public let releaseId: String
  public let commitSha: String
  public let verifiedOnDevice: Bool
  public let artifactRef: String
  public let retentionRank: Int

  public init(
    releaseId: String,
    commitSha: String,
    verifiedOnDevice: Bool,
    artifactRef: String,
    retentionRank: Int
  ) {
    self.releaseId = releaseId
    self.commitSha = commitSha
    self.verifiedOnDevice = verifiedOnDevice
    self.artifactRef = artifactRef
    self.retentionRank = retentionRank
  }

  public static func retainLatest(
    _ candidates: [RollbackCandidate],
    minimumCount: Int = 3
  ) -> [RollbackCandidate] {
    let sorted = candidates.sorted { $0.retentionRank < $1.retentionRank }
    let keepCount = min(candidates.count, minimumCount)
    return Array(sorted.prefix(keepCount))
  }
}
