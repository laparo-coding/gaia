import Foundation
import GaiaCore

public enum FeatureCatalogError: Error, LocalizedError {
  case invalidSpecsRoot(URL)
  case invalidSlug(String)
  case featureAlreadyExists(String)
  case invalidPreviewArtifact(String)
  case invalidPreviewProfile(String)
  case missingSlugArgument
  case missingOptionValue(String)
  case unknownOption(String)

  public var errorDescription: String? {
    switch self {
    case let .invalidSpecsRoot(url):
      return "Specs directory not found at \(url.path)."
    case let .invalidSlug(slug):
      return "Invalid feature slug '\(slug)'. Use lowercase letters, numbers, and hyphens."
    case let .featureAlreadyExists(path):
      return "Feature scaffold already exists at \(path)."
    case let .invalidPreviewArtifact(name):
      return "Invalid preview artifact '\(name)'. Use spec.md, plan.md, or tasks.md."
    case let .invalidPreviewProfile(name):
      return "Invalid preview profile '\(name)'. Use all, planning, overview, or execution."
    case .missingSlugArgument:
      return
        "Missing slug. Usage: swift run GaiaCLI new-feature <slug> [--title|-t <title>] [--summary|-s <summary>] [--description|-d <description>] [--dry-run|-n] [--preview|-p <artifact>] [--preview-profile|-P <profile>] [--json|-j]"
    case let .missingOptionValue(option):
      return "Missing value for option \(option)."
    case let .unknownOption(option):
      return "Unknown option \(option)."
    }
  }
}

public struct FeatureScaffold: Sendable {
  public static let previewProfiles: [String: [String]] = [
    "all": ["spec.md", "plan.md", "tasks.md"],
    "planning": ["spec.md", "plan.md"],
    "overview": ["spec.md"],
    "execution": ["plan.md", "tasks.md"],
  ]

  public let descriptor: FeatureDescriptor
  public let spec: String
  public let plan: String
  public let tasks: String

  public init(descriptor: FeatureDescriptor, spec: String, plan: String, tasks: String) {
    self.descriptor = descriptor
    self.spec = spec
    self.plan = plan
    self.tasks = tasks
  }

  public func orderedArtifacts() -> [(name: String, content: String)] {
    [
      (name: "spec.md", content: spec),
      (name: "plan.md", content: plan),
      (name: "tasks.md", content: tasks),
    ]
  }

  public func selectedArtifacts(named requestedNames: [String]) throws -> [(
    name: String, content: String
  )] {
    if requestedNames.isEmpty {
      return orderedArtifacts()
    }

    let availableArtifacts = Dictionary(
      uniqueKeysWithValues: orderedArtifacts().map { ($0.name, $0.content) })
    return try requestedNames.map { requestedName in
      guard let content = availableArtifacts[requestedName] else {
        throw FeatureCatalogError.invalidPreviewArtifact(requestedName)
      }
      return (name: requestedName, content: content)
    }
  }

  public static func artifacts(forProfile profileName: String) throws -> [String] {
    let normalizedName = profileName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard let artifacts = previewProfiles[normalizedName] else {
      throw FeatureCatalogError.invalidPreviewProfile(profileName)
    }

    return artifacts
  }
}

public struct FeatureDescriptor: Sendable, Hashable, Codable {
  public let index: Int
  public let slug: String
  public let title: String
  public let summary: String

  public init(index: Int, slug: String, title: String, summary: String) {
    precondition(index > 0, "Feature indices must be positive.")
    precondition(!slug.isEmpty, "Feature slugs must not be empty.")
    self.index = index
    self.slug = slug
    self.title = title
    self.summary = summary
  }

  public var branchName: String {
    let rawIndex = String(index)
    let prefix = String(repeating: "0", count: max(0, 3 - rawIndex.count))
    return "\(prefix)\(rawIndex)-\(slug)"
  }

  public var specDirectory: String {
    "specs/\(branchName)"
  }

  public var requiredArtifacts: [String] {
    ["spec.md", "plan.md", "tasks.md"]
  }

  public func summaryLine() -> String {
    "\(branchName): \(title)"
  }

  public static func displayTitle(for slug: String) -> String {
    slug
      .split(separator: "-")
      .map { token in
        let word = String(token)
        guard let first = word.first else {
          return word
        }
        return first.uppercased() + word.dropFirst()
      }
      .joined(separator: " ")
  }

  public static func normalizedSlug(from rawValue: String) throws -> String {
    let lowercased =
      rawValue
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    let separated = lowercased.replacingOccurrences(
      of: "[^a-z0-9]+",
      with: "-",
      options: .regularExpression
    )
    let collapsed = separated.replacingOccurrences(
      of: "-{2,}",
      with: "-",
      options: .regularExpression
    )
    let trimmed = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-"))

    guard !trimmed.isEmpty else {
      throw FeatureCatalogError.invalidSlug(rawValue)
    }

    return trimmed
  }
}

public struct FeatureCatalog: Sendable {
  public let blueprint: ProjectBlueprint
  public let features: [FeatureDescriptor]

  public init(
    blueprint: ProjectBlueprint = ProjectBlueprint(),
    features: [FeatureDescriptor]
  ) {
    self.blueprint = blueprint
    self.features = features.sorted { left, right in
      left.index < right.index
    }
  }

  public static func discover(
    in specsDirectory: URL,
    blueprint: ProjectBlueprint = ProjectBlueprint(),
    fileManager: FileManager = .default
  ) throws -> FeatureCatalog {
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: specsDirectory.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      throw FeatureCatalogError.invalidSpecsRoot(specsDirectory)
    }

    let entries = try fileManager.contentsOfDirectory(
      at: specsDirectory,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    )

    let features = try entries.compactMap { entry -> FeatureDescriptor? in
      let values = try entry.resourceValues(forKeys: [.isDirectoryKey])
      guard values.isDirectory == true else {
        return nil
      }

      return try FeatureDescriptor.make(from: entry, fileManager: fileManager)
    }

    return FeatureCatalog(blueprint: blueprint, features: features)
  }

  public func nextSpecDirectory() -> String {
    let nextDescriptor = nextFeatureDescriptor(
      slug: "new-feature",
      title: "New Feature",
      summary: "Describe the next feature."
    )
    return nextDescriptor.specDirectory
  }

  public func nextFeatureDescriptor(
    slug rawSlug: String,
    title: String,
    summary: String
  ) -> FeatureDescriptor {
    let nextIndex = (features.map(\.index).max() ?? 0) + 1
    let slug = (try? FeatureDescriptor.normalizedSlug(from: rawSlug)) ?? rawSlug
    return FeatureDescriptor(
      index: nextIndex,
      slug: slug,
      title: title,
      summary: summary
    )
  }

  public func scaffoldNextFeature(
    slug rawSlug: String,
    title requestedTitle: String?,
    summary: String,
    description: String?,
    in repositoryRoot: URL,
    fileManager: FileManager = .default
  ) throws -> FeatureDescriptor {
    let scaffold = try preparedScaffold(
      slug: rawSlug,
      title: requestedTitle,
      summary: summary,
      description: description
    )
    let directory = repositoryRoot.appendingPathComponent(
      scaffold.descriptor.specDirectory,
      isDirectory: true
    )

    guard !fileManager.fileExists(atPath: directory.path) else {
      throw FeatureCatalogError.featureAlreadyExists(directory.path)
    }

    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

    try scaffold.spec.write(
      to: directory.appendingPathComponent("spec.md"),
      atomically: true,
      encoding: .utf8
    )
    try scaffold.plan.write(
      to: directory.appendingPathComponent("plan.md"),
      atomically: true,
      encoding: .utf8
    )
    try scaffold.tasks.write(
      to: directory.appendingPathComponent("tasks.md"),
      atomically: true,
      encoding: .utf8
    )

    return scaffold.descriptor
  }

  public func preparedScaffold(
    slug rawSlug: String,
    title requestedTitle: String?,
    summary: String,
    description: String?
  ) throws -> FeatureScaffold {
    let slug = try FeatureDescriptor.normalizedSlug(from: rawSlug)
    let title = requestedTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
    let cleanedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
    let cleanedDescription = description?.trimmingCharacters(in: .whitespacesAndNewlines)
    let resolvedTitle: String
    if let title, !title.isEmpty {
      resolvedTitle = title
    } else {
      resolvedTitle = FeatureDescriptor.displayTitle(for: slug)
    }

    let descriptor = nextFeatureDescriptor(
      slug: slug,
      title: resolvedTitle,
      summary: cleanedSummary
    )
    return FeatureScaffold(
      descriptor: descriptor,
      spec: renderSpec(for: descriptor, description: cleanedDescription),
      plan: renderPlan(for: descriptor),
      tasks: renderTasks(for: descriptor)
    )
  }

  public func summary() -> String {
    let titles = features.map { $0.summaryLine() }.joined(separator: "; ")
    let nextSlot = nextSpecDirectory()
    let currentEntries = "\(blueprint.name) feature catalog ready. Current entries: \(titles)."
    return "\(currentEntries) Next slot: \(nextSlot)."
  }

  private func renderSpec(for descriptor: FeatureDescriptor, description: String?) -> String {
    let date = Self.currentDateString()
    let inputDescription = description ?? "[TODO]"
    return """
      # Feature Specification: \(descriptor.title)

      **Feature Branch**: `\(descriptor.branchName)`  
      **Created**: \(date)  
      **Status**: Draft  
      **Input**: User description: \"\(inputDescription)\"

      ## User Scenarios & Testing

      ### Primary User Story

      [Describe the primary user journey and why this feature matters. Start from: \(descriptor.summary)]

      ### Acceptance Scenarios

      1. **Given** [initial state], **When** [action], **Then** [expected outcome]
      2. **Given** [initial state], **When** [action], **Then** [expected outcome]

      ### Edge Cases

      - What happens when [boundary condition]?
      - How does the user recover when the workflow is degraded or incomplete?

      ## Requirements

      ### Functional Requirements

      - **FR-001**: System MUST [specific capability]
      - **FR-002**: System MUST [validation or lifecycle rule]
      - **FR-003**: System MUST [security, observability, or failure-handling behavior]

      ### Key Entities

      - **[Entity 1]**: [What it represents]
      - **[Entity 2]**: [What it represents]
      """
  }

  private func renderPlan(for descriptor: FeatureDescriptor) -> String {
    let date = Self.currentDateString()
    return """
      # Implementation Plan: \(descriptor.title)

      **Branch**: `\(descriptor.branchName)` | **Date**: \(date) | **Spec**: [spec.md](spec.md)

      ## Summary

      \(descriptor.summary)

      ## Technical Context

      **Language/Version**: Swift 6.x  
      **Primary Dependencies**: NEEDS CLARIFICATION  
      **Storage**: NEEDS CLARIFICATION  
      **Testing**: NEEDS CLARIFICATION  
      **Target Platform**: NEEDS CLARIFICATION  
      **Project Type**: swift-package  
      **Editor Workflow**: VS Code + swiftlang.swift-vscode

      ## Constitution Check

      - [ ] Specs-first flow preserved
      - [ ] Tests planned before implementation
      - [ ] Structure uses active Swift package layout
      - [ ] Security, observability, and failure handling are covered

      ## Project Structure

      [Document the concrete paths for this feature once the design is approved.]
      """
  }

  private func renderTasks(for descriptor: FeatureDescriptor) -> String {
    """
    # Tasks: \(descriptor.title)

    **Input**: `/specs/\(descriptor.branchName)/plan.md`

    ## Phase 3.1: Setup

    - [ ] T001 Confirm scope and concrete target paths from `plan.md`
    - [ ] T002 Create or update tests before implementation

    ## Phase 3.2: Implementation

    - [ ] T003 Implement the feature in the planned Swift targets
    - [ ] T004 Add logging, validation, and failure-handling behavior

    ## Phase 3.3: Polish

    - [ ] T005 Update docs and run build/lint/test validation
    """
  }

  private static func currentDateString() -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: Date())
  }
}

private extension FeatureDescriptor {
  static func make(from directory: URL, fileManager: FileManager) throws -> FeatureDescriptor? {
    let name = directory.lastPathComponent
    let parts = name.split(separator: "-", maxSplits: 1).map(String.init)
    guard parts.count == 2, let index = Int(parts[0]) else {
      return nil
    }

    let slug = parts[1]
    let specURL = directory.appendingPathComponent("spec.md")
    let title = specTitle(from: specURL, fileManager: fileManager) ?? displayTitle(for: slug)

    return FeatureDescriptor(
      index: index,
      slug: slug,
      title: title,
      summary: "See \(name)/spec.md for details."
    )
  }

  static func specTitle(from url: URL, fileManager: FileManager) -> String? {
    guard fileManager.fileExists(atPath: url.path),
      let content = try? String(contentsOf: url, encoding: .utf8)
    else {
      return nil
    }

    for line in content.split(separator: "\n") {
      if line.hasPrefix("# Feature Specification: ") {
        return String(line.dropFirst("# Feature Specification: ".count))
      }
    }

    return nil
  }
}
