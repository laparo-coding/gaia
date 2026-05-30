public struct DeploymentEligibilityService {
  public struct Input {
    public let ciPassed: Bool
    public let reviewEvaluation: ReviewGateEvaluation
    public let reviewPolicy: ReviewGatePolicy
    public let run: DeploymentRun
    public let signingBundle: SigningBundle

    public init(
      ciPassed: Bool,
      reviewEvaluation: ReviewGateEvaluation,
      reviewPolicy: ReviewGatePolicy,
      run: DeploymentRun,
      signingBundle: SigningBundle
    ) {
      self.ciPassed = ciPassed
      self.reviewEvaluation = reviewEvaluation
      self.reviewPolicy = reviewPolicy
      self.run = run
      self.signingBundle = signingBundle
    }
  }

  public enum Decision: Equatable {
    case eligible
    case ineligible(reason: String)
  }

  public init() {}

  public func evaluate(_ input: Input) -> Decision {
    guard input.ciPassed else {
      return .ineligible(reason: "CI baseline failed")
    }

    guard input.reviewPolicy.isSatisfied(by: input.reviewEvaluation) else {
      return .ineligible(reason: "Review gates not satisfied")
    }

    guard input.run.hasValidTriggerRole() else {
      return .ineligible(reason: "Deploy trigger requires admin")
    }

    guard input.run.isDeploymentSourceValid() else {
      return .ineligible(reason: "Deploy source must be semver tag on main")
    }

    guard input.signingBundle.validate() == .valid else {
      return .ineligible(reason: "Signing bundle invalid")
    }

    return .eligible
  }
}
