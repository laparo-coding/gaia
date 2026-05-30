import Foundation

public struct CIGateEvaluator {
  public enum Gate: String, CaseIterable {
    case format
    case lint
    case build
    case test
    case reviewGates
  }

  public struct Input {
    public let formatPassed: Bool
    public let lintPassed: Bool
    public let buildPassed: Bool
    public let testPassed: Bool
    public let reviewGatePassed: Bool

    public init(
      formatPassed: Bool,
      lintPassed: Bool,
      buildPassed: Bool,
      testPassed: Bool,
      reviewGatePassed: Bool
    ) {
      self.formatPassed = formatPassed
      self.lintPassed = lintPassed
      self.buildPassed = buildPassed
      self.testPassed = testPassed
      self.reviewGatePassed = reviewGatePassed
    }
  }

  public struct Result {
    public let gateResults: [Gate: Bool]

    public var passed: Bool {
      gateResults.values.allSatisfy { $0 }
    }

    public var failedGates: [Gate] {
      gateResults.compactMap { key, value in
        value ? nil : key
      }
    }
  }

  public init() {}

  public func evaluate(_ input: Input) -> Result {
    Result(
      gateResults: [
        .format: input.formatPassed,
        .lint: input.lintPassed,
        .build: input.buildPassed,
        .test: input.testPassed,
        .reviewGates: input.reviewGatePassed,
      ]
    )
  }
}
