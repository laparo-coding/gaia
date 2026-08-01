import Foundation
import Testing

@testable import GaiaCore

@Suite(.serialized)
struct StreamGetContractTests {
  @Test
  func missingLocationHeaderMapsToInvalidResponse() async throws {
    let runtime = try PlaybackTestSupport.makeRuntime(aitherToken: "aither-test-token")
    let downstream = DownstreamServiceClient(runtime: runtime) { request in
      let response = HTTPURLResponse(
        url: request.url!, statusCode: 302, httpVersion: nil,
        headerFields: [:])!
      return (Data(), response)
    }
    let client = PlaybackClient(
      baseURL: PlaybackTestSupport.aitherBaseURL,
      downstreamClient: downstream,
      cacheTTL: 60)

    let result = await client.resolvePlaybackURL(assetId: "rec_test", requestID: "req-1")
    let error = try #require(result.playbackError)
    #expect(error == .invalidResponse)
  }
}
