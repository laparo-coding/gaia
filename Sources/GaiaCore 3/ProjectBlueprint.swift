public struct ProjectBlueprint: Sendable {
  public let name: String

  public init(name: String = "Gaia") {
    self.name = name
  }

  public func recommendedDirectories() -> [String] {
    [
      ".github/workflows",
      ".vscode",
      "Documentation.docc",
      "Sources",
      "Tests",
      "specs",
    ]
  }

  public func summary() -> String {
    let directories = recommendedDirectories().joined(separator: ", ")
    return "\(name) Swift workspace ready. Expected directories: \(directories)."
  }
}
