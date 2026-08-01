import Foundation
import Testing

@testable import GaiaCore

@Suite(.serialized)
struct ChaptersPostContractTests {
  @Test
  func postRequestCarriesBearerAndDecodesRegenerationResult() async throws {
    let runtime = try PlaybackTestSupport.makeRuntime(aitherToken: "aither-test-token")
    let assetId = "rec_2026-07-13T10-30-00Z"
    let recorder = BearerHeaderRecorder(expectedToken: "aither-test-token")
    let downstream = DownstreamServiceClient(runtime: runtime) { request in
      await recorder.record(authorization: request.value(forHTTPHeaderField: "Authorization"))
      let body = PlaybackTestSupport.regenerationResultBody(
        assetId: assetId, muxAssetId: "mux_test", chapterCount: 5)
      let response = PlaybackTestSupport.response(for: request, statusCode: 200)
      return (body, response)
    }
    let client = PlaybackClient(
      baseURL: PlaybackTestSupport.aitherBaseURL,
      downstreamClient: downstream,
      cacheTTL: 60)

    let result = await client.regenerate(assetId: assetId, requestID: "req-1")

    #expect(await recorder.allCarriedBearer)
    #expect(await recorder.requestCount > 0)
    let regeneration = try #require(result.value)
    #expect(regeneration.assetId == assetId)
    #expect(regeneration.muxAssetId == "mux_test")
    #expect(regeneration.chapterCount == 5)
  }

  @Test
  func recordingInProgressMapsToPlaybackError() async throws {
    let error = try await regenerateError(code: "RECORDING_IN_PROGRESS", statusCode: 409)
    #expect(error == .recordingInProgress)
  }

  @Test
  func ffmetadataInvalidMapsToPlaybackError() async throws {
    let error = try await regenerateError(code: "FFMETADATA_INVALID", statusCode: 422)
    #expect(error == .ffmetadataInvalid)
  }

  @Test
  func remuxFailedMapsToPlaybackError() async throws {
    let error = try await regenerateError(code: "REMUX_FAILED", statusCode: 502)
    #expect(error == .remuxFailed)
  }

  @Test
  func blobStorageUnavailableMapsToPlaybackError() async throws {
    let error = try await regenerateError(code: "BLOB_STORAGE_UNAVAILABLE", statusCode: 503)
    #expect(error == .blobStorageUnavailable)
  }

  private func regenerateError(code: String, statusCode: Int) async throws -> PlaybackError {
    let runtime = try PlaybackTestSupport.makeRuntime(aitherToken: "aither-test-token")
    let downstream = DownstreamServiceClient(runtime: runtime) { request in
      let body = PlaybackTestSupport.errorBody(code: code, message: "failure")
      let response = PlaybackTestSupport.response(for: request, statusCode: statusCode)
      return (body, response)
    }
    let client = PlaybackClient(
      baseURL: PlaybackTestSupport.aitherBaseURL,
      downstreamClient: downstream,
      cacheTTL: 60)
    let result = await client.regenerate(assetId: "rec_test", requestID: "req-1")
    return try #require(result.playbackError)
  }
}


