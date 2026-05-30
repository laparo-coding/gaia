import Testing

@testable import GaiaCore

struct ProjectBlueprintTests {
  @Test
  func summaryMentionsSwiftWorkspace() {
    let blueprint = ProjectBlueprint()

    #expect(blueprint.summary().contains("Swift workspace ready"))
  }

  @Test
  func recommendedDirectoriesContainSpeckitAndSources() {
    let blueprint = ProjectBlueprint()

    #expect(blueprint.recommendedDirectories().contains("Sources"))
    #expect(blueprint.recommendedDirectories().contains("specs"))
  }
}
