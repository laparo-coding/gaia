import Foundation
import Testing

@testable import GaiaFeatureCatalog

struct FeatureCatalogTests {
  @Test
  func featureDescriptorBuildsSpecDirectoryFromIndexAndSlug() {
    let descriptor = FeatureDescriptor(
      index: 7,
      slug: "sync-engine",
      title: "Sync Engine",
      summary: "Synchronize feature artifacts."
    )

    #expect(descriptor.branchName == "007-sync-engine")
    #expect(descriptor.specDirectory == "specs/007-sync-engine")
  }

  @Test
  func discoveredCatalogSuggestsNextFeatureSlot() throws {
    let root = try temporaryDirectory()
    let specs = root.appendingPathComponent("specs", isDirectory: true)
    try FileManager.default.createDirectory(at: specs, withIntermediateDirectories: true)
    let bootstrap = specs.appendingPathComponent("001-swift-workspace-bootstrap", isDirectory: true)
    try FileManager.default.createDirectory(at: bootstrap, withIntermediateDirectories: true)
    try "# Feature Specification: Swift Workspace Bootstrap\n".write(
      to: bootstrap.appendingPathComponent("spec.md"),
      atomically: true,
      encoding: .utf8
    )

    let catalog = try FeatureCatalog.discover(in: specs)

    #expect(catalog.features.count == 1)
    #expect(catalog.nextSpecDirectory() == "specs/002-new-feature")
  }

  @Test
  func scaffoldCreatesNextFeatureArtifacts() throws {
    let root = try temporaryDirectory()
    let specs = root.appendingPathComponent("specs", isDirectory: true)
    try FileManager.default.createDirectory(at: specs, withIntermediateDirectories: true)
    let bootstrap = specs.appendingPathComponent("001-swift-workspace-bootstrap", isDirectory: true)
    try FileManager.default.createDirectory(at: bootstrap, withIntermediateDirectories: true)
    try "# Feature Specification: Swift Workspace Bootstrap\n".write(
      to: bootstrap.appendingPathComponent("spec.md"),
      atomically: true,
      encoding: .utf8
    )

    let catalog = try FeatureCatalog.discover(in: specs)
    let descriptor = try catalog.scaffoldNextFeature(
      slug: "feature-catalog-discovery",
      title: "Feature Catalog Discovery",
      summary: "Discover spec folders from disk.",
      description: "Scan existing spec folders and scaffold the next one.",
      in: root,
      fileManager: .default
    )

    #expect(descriptor.specDirectory == "specs/002-feature-catalog-discovery")
    #expect(
      FileManager.default.fileExists(
        atPath: root.appendingPathComponent("specs/002-feature-catalog-discovery/spec.md").path
      )
    )
    #expect(
      FileManager.default.fileExists(
        atPath: root.appendingPathComponent("specs/002-feature-catalog-discovery/plan.md").path
      )
    )
    #expect(
      FileManager.default.fileExists(
        atPath: root.appendingPathComponent("specs/002-feature-catalog-discovery/tasks.md").path
      )
    )
  }

  @Test
  func preparedScaffoldCarriesSummaryAndDescriptionIntoTemplates() throws {
    let root = try temporaryDirectory()
    let specs = root.appendingPathComponent("specs", isDirectory: true)
    try FileManager.default.createDirectory(at: specs, withIntermediateDirectories: true)

    let catalog = try FeatureCatalog.discover(in: specs)
    let scaffold = try catalog.preparedScaffold(
      slug: "cli-option-support",
      title: "CLI Option Support",
      summary: "Add summary, description, and dry-run support.",
      description: "Create richer feature scaffolds from CLI arguments."
    )

    #expect(scaffold.descriptor.specDirectory == "specs/001-cli-option-support")
    #expect(scaffold.spec.contains("Create richer feature scaffolds from CLI arguments."))
    #expect(scaffold.plan.contains("Add summary, description, and dry-run support."))
    #expect(scaffold.tasks.contains("# Tasks: CLI Option Support"))
  }

  @Test
  func selectedArtifactsReturnsRequestedSubsetInRequestedOrder() throws {
    let descriptor = FeatureDescriptor(
      index: 4,
      slug: "cli-json-preview",
      title: "CLI JSON Preview",
      summary: "Expose machine-readable output."
    )
    let scaffold = FeatureScaffold(
      descriptor: descriptor,
      spec: "spec-content",
      plan: "plan-content",
      tasks: "tasks-content"
    )

    let selected = try scaffold.selectedArtifacts(named: ["tasks.md", "spec.md"])

    #expect(selected.count == 2)
    #expect(selected[0].name == "tasks.md")
    #expect(selected[0].content == "tasks-content")
    #expect(selected[1].name == "spec.md")
    #expect(selected[1].content == "spec-content")
  }

  @Test
  func selectedArtifactsRejectsUnknownArtifactNames() throws {
    let descriptor = FeatureDescriptor(
      index: 4,
      slug: "cli-json-preview",
      title: "CLI JSON Preview",
      summary: "Expose machine-readable output."
    )
    let scaffold = FeatureScaffold(
      descriptor: descriptor,
      spec: "spec-content",
      plan: "plan-content",
      tasks: "tasks-content"
    )

    #expect(throws: FeatureCatalogError.self) {
      _ = try scaffold.selectedArtifacts(named: ["notes.md"])
    }
  }

  @Test
  func previewProfileResolvesExpectedArtifacts() throws {
    let planningArtifacts = try FeatureScaffold.artifacts(forProfile: "planning")
    let executionArtifacts = try FeatureScaffold.artifacts(forProfile: "execution")

    #expect(planningArtifacts == ["spec.md", "plan.md"])
    #expect(executionArtifacts == ["plan.md", "tasks.md"])
  }

  @Test
  func previewProfileRejectsUnknownNames() throws {
    #expect(throws: FeatureCatalogError.self) {
      _ = try FeatureScaffold.artifacts(forProfile: "custom")
    }
  }

  private func temporaryDirectory() throws -> URL {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
  }
}
