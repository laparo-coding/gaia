import Foundation

public struct PipelineStage: Equatable {
  public enum Kind: String, Equatable {
    case ci
    case deploy
  }

  public enum Status: String, Equatable {
    case pending
    case running
    case passed
    case failed
    case skipped
  }

  public let id: String
  public let name: String
  public let kind: Kind
  public private(set) var status: Status
  public private(set) var startedAt: Date?
  public private(set) var finishedAt: Date?

  public init(
    id: String,
    name: String,
    kind: Kind,
    status: Status = .pending,
    startedAt: Date? = nil,
    finishedAt: Date? = nil
  ) {
    self.id = id
    self.name = name
    self.kind = kind
    self.status = status
    self.startedAt = startedAt
    self.finishedAt = finishedAt
  }

  public mutating func transition(to next: Status, at date: Date = Date()) -> Bool {
    guard Self.canTransition(from: status, to: next) else {
      return false
    }

    if next == .running && startedAt == nil {
      startedAt = date
    }

    if [.passed, .failed, .skipped].contains(next) {
      finishedAt = date
    }

    status = next
    return true
  }

  private static func canTransition(from: Status, to: Status) -> Bool {
    switch from {
    case .pending:
      return to == .running || to == .skipped
    case .running:
      return to == .passed || to == .failed || to == .skipped
    case .passed, .failed, .skipped:
      return false
    }
  }
}
