import Foundation
import Testing

@testable import GaiaCore

@Suite(.serialized)
struct ChaptersGetContractTests {
  @Test
  func getRequestCarriesBearerAndDecodesChapterList() async throws {
    let runtime = try PlaybackTestSupport.makeRuntime(aitherToken: "aither-test-token")
    let assetId = "rec_2026-07-13T10-30-00Z"
    let recorder = BearerHeaderRecorder(expectedToken: "aither-test-token")
    let downstream = DownstreamServiceClient(runtime: runtime) { request in
      await recorder.record(authorization: request.value(forHTTPHeaderField: "Authorization"))
      let body = PlaybackTestSupport.chapterListBody(assetId: assetId)
      let response = PlaybackTestSupport.response(for: request, statusCode: 200)
      return (body, response)
    }
    let client = PlaybackClient(
      baseURL: PlaybackTestSupport.aitherBaseURL,
      downstreamClient: downstream,
      cacheTTL: 60)

    let result = await client.fetchChapters(assetId: assetId, requestID: "req-1")

    #expect(await recorder.allCarriedBearer)
    #expect(await recorder.requestCount == 1)
    let chapters = try #require(result.value)
    #expect(chapters.assetId == assetId)
    #expect(chapters.chapters.count == 2)
    #expect(chapters.chapters[0].start == 0.0)
  }

  @Test
  func chaptersNotGeneratedMapsToPlaybackError() async throws {
    let error = try await fetchError(code: "CHAPTERS_NOT_GENERATED", statusCode: 404)
    #expect(error == .chaptersNotGenerated)
  }

  @Test
  func recordingNotFoundMapsToPlaybackError() async throws {
    let error = try await fetchError(code: "RECORDING_NOT_FOUND", statusCode: 404)
    #expect(error == .recordingNotFound)
  }

  private func fetchError(code: String, statusCode: Int) async throws -> PlaybackError {
    let runtime = try PlaybackTestSupport.makeRuntime(aitherToken: "aither-test-token")
    let downstream = DownstreamServiceClient(runtime: runtime) { request in
      let body = PlaybackTestSupport.errorBody(code: code, message: "none")
      let response = PlaybackTestSupport.response(for: request, statusCode: statusCode)
      return (body, response)
    }
    let client = PlaybackClient(
      baseURL: PlaybackTestSupport.aitherBaseURL,
      downstreamClient: downstream,
      cacheTTL: 60)
    let result = await client.fetchChapters(assetId: "rec_test", requestID: "req-1")
    return try #require(result.playbackError)
  }
}


