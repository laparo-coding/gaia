public struct ReviewGatePolicy: Equatable {
  public enum SourcePolicy: String, Equatable {
    case mirrorAitherApplicable
  }

  public let sourcePolicy: SourcePolicy
  public let requiresHumanApproval: Bool
  public let requiresAutomatedReviewGate: Bool
  public let blocksOnUnresolvedBlockingComments: Bool

  public init(
    sourcePolicy: SourcePolicy = .mirrorAitherApplicable,
    requiresHumanApproval: Bool = true,
    requiresAutomatedReviewGate: Bool = true,
    blocksOnUnresolvedBlockingComments: Bool = true
  ) {
    self.sourcePolicy = sourcePolicy
    self.requiresHumanApproval = requiresHumanApproval
    self.requiresAutomatedReviewGate = requiresAutomatedReviewGate
    self.blocksOnUnresolvedBlockingComments = blocksOnUnresolvedBlockingComments
  }

  public func isSatisfied(by input: ReviewGateEvaluation) -> Bool {
    if requiresHumanApproval && !input.hasHumanApproval {
      return false
    }

    if requiresAutomatedReviewGate && !input.automatedGatePassed {
      return false
    }

    if blocksOnUnresolvedBlockingComments && input.unresolvedBlockingComments > 0 {
      return false
    }

    return true
  }
}

public struct ReviewGateEvaluation: Equatable {
  public let hasHumanApproval: Bool
  public let automatedGatePassed: Bool
  public let unresolvedBlockingComments: Int

  public init(
    hasHumanApproval: Bool,
    automatedGatePassed: Bool,
    unresolvedBlockingComments: Int
  ) {
    self.hasHumanApproval = hasHumanApproval
    self.automatedGatePassed = automatedGatePassed
    self.unresolvedBlockingComments = unresolvedBlockingComments
  }
}
