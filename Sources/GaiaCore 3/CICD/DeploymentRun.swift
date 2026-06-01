public struct DeploymentRun: Equatable, Sendable {
  public enum TriggerRole: String, Equatable, Sendable {
    case admin
    case nonAdmin
  }

  public enum Status: String, Equatable, Sendable {
    case pending
    case running
    case succeeded
    case failed
    case aborted
  }

  public let runId: String
  public let triggeredBy: String
  public let triggeredByRole: TriggerRole
  public let targetCommit: String
  public let targetBranch: String
  public let targetTag: String
  public let status: Status
  public let logRef: String?
  public let artifactRef: String?

  public init(
    runId: String,
    triggeredBy: String,
    triggeredByRole: TriggerRole,
    targetCommit: String,
    targetBranch: String,
    targetTag: String,
    status: Status,
    logRef: String? = nil,
    artifactRef: String? = nil
  ) {
    self.runId = runId
    self.triggeredBy = triggeredBy
    self.triggeredByRole = triggeredByRole
    self.targetCommit = targetCommit
    self.targetBranch = targetBranch
    self.targetTag = targetTag
    self.status = status
    self.logRef = logRef
    self.artifactRef = artifactRef
  }

  public func isDeploymentSourceValid() -> Bool {
    targetBranch == "main" && SemverTagValidator.isValid(targetTag)
  }

  public func hasValidTriggerRole() -> Bool {
    triggeredByRole == .admin
  }
}
