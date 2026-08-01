import Foundation
import Testing

@testable import GaiaCore

@Suite(.serialized)
struct PlaybackFlowTests {
  @Test
  func loadChaptersThenNextChapterSeek() async throws {
    let runtime = try PlaybackTestSupport.makeRuntime()
    let assetId = "rec_flow_test"
    let downstream = DownstreamServiceClient(runtime: runtime) { request in
      let body = PlaybackTestSupport.chapterListBody(assetId: assetId)
      let response = PlaybackTestSupport.response(for: request, statusCode: 200)
      return (body, response)
    }
    let client = PlaybackClient(
      baseURL: PlaybackTestSupport.aitherBaseURL,
      downstreamClient: downstream,
      cacheTTL: 60)
    let chapters = try #require(
      await client.fetchChapters(assetId: assetId, requestID: "req-1").value)

    #expect(ChapterSeekLogic.nextChapter(chapters: chapters.chapters, currentPosition: 5.0) != nil)
    let nextChapter = try #require(
      ChapterSeekLogic.nextChapter(chapters: chapters.chapters, currentPosition: 5.0))
    #expect(nextChapter.start == 10.0)
    #expect(ChapterSeekLogic.nextChapter(chapters: chapters.chapters, currentPosition: 25.0) == nil)
  }

  @Test
  func chaptersNotGeneratedMapsToDisabledState() async throws {
    let runtime = try PlaybackTestSupport.makeRuntime()
    let downstream = DownstreamServiceClient(runtime: runtime) { request in
      let body = PlaybackTestSupport.errorBody(code: "CHAPTERS_NOT_GENERATED", message: "none")
      let response = PlaybackTestSupport.response(for: request, statusCode: 404)
      return (body, response)
    }
    let client = PlaybackClient(
      baseURL: PlaybackTestSupport.aitherBaseURL,
      downstreamClient: downstream,
      cacheTTL: 60)

    let result = await client.fetchChapters(assetId: "rec_test", requestID: "req-1")
    let error = try #require(result.playbackError)
    #expect(error == .chaptersNotGenerated)
  }

  @Test
  func regenerationRefreshesChapterList() async throws {
    let runtime = try PlaybackTestSupport.makeRuntime()
    let assetId = "rec_regen_test"
    let chapterCount = ChapterCount(initialValue: 2)
    let downstream = DownstreamServiceClient(runtime: runtime) { request in
      if request.httpMethod == "POST" {
        await chapterCount.set(3)
        let body = PlaybackTestSupport.regenerationResultBody(
          assetId: assetId, muxAssetId: "mux_test", chapterCount: 3)
        let response = PlaybackTestSupport.response(for: request, statusCode: 200)
        return (body, response)
      }
      let count = await chapterCount.value
      let body = PlaybackTestSupport.chapterListBody(assetId: assetId, chapterCount: count)
      let response = PlaybackTestSupport.response(for: request, statusCode: 200)
      return (body, response)
    }
    let client = PlaybackClient(
      baseURL: PlaybackTestSupport.aitherBaseURL,
      downstreamClient: downstream,
      cacheTTL: 60)

    let before = try #require(
      await client.fetchChapters(assetId: assetId, requestID: "req-1").value)
    #expect(before.chapters.count == 2)
    _ = await client.regenerate(assetId: assetId, requestID: "req-2")
    let after = try #require(
      await client.fetchChapters(assetId: assetId, requestID: "req-3").value)
    #expect(after.chapters.count == 3)
  }

}

private actor ChapterCount {
  private var storage: Int

  init(initialValue: Int) {
    storage = initialValue
  }

  var value: Int { storage }

  func set(_ value: Int) {
    storage = value
  }
}
