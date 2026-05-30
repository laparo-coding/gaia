public struct ArtifactRetentionService {
  public init() {}

  public func retainLatestThree(
    candidates: [RollbackCandidate]
  ) -> [RollbackCandidate] {
    let sorted = candidates.sorted { $0.retentionRank < $1.retentionRank }
    return Array(sorted.prefix(3))
  }
}
