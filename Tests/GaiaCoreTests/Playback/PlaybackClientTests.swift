import Foundation
import Testing

@testable import GaiaCore

/// Unit tests for `PlaybackClient` (Spec 010, FR-003 + FR-005 + FR-007):
/// chapter list fetch with cache, regeneration trigger, error mapping, and
/// cache invalidation on regeneration success.
@Suite(.serialized)
struct PlaybackClientTests {
  @Test
  func cachesChapterListWithinTTL() async throws {
    let runtime = try PlaybackTestSupport.makeRuntime()
    let assetId = "rec_cache_test"
    let counter = FetchCounter()

    let downstream = DownstreamServiceClient(runtime: runtime) { request in
      await counter.increment()
      let body = PlaybackTestSupport.chapterListBody(assetId: assetId)
      let response = PlaybackTestSupport.response(for: request, statusCode: 200)
      return (body, response)
    }

    let client = PlaybackClient(
      baseURL: PlaybackTestSupport.aitherBaseURL,
      downstreamClient: downstream,
      cacheTTL: 60)

    _ = await client.fetchChapters(assetId: assetId, requestID: "req-1")
    _ = await client.fetchChapters(assetId: assetId, requestID: "req-2")

    // Second fetch served from cache (research R3): only one network call.
    let count = await counter.value
    #expect(count == 1)
  }

  @Test
  func invalidatesCacheAfterRegeneration() async throws {
    let runtime = try PlaybackTestSupport.makeRuntime()
    let assetId = "rec_invalidate_test"
    let counter = FetchCounter()

    let downstream = DownstreamServiceClient(runtime: runtime) { request in
      if request.httpMethod == "POST" {
        let body = PlaybackTestSupport.regenerationResultBody(
          assetId: assetId, muxAssetId: "mux_test", chapterCount: 2)
        let response = PlaybackTestSupport.response(for: request, statusCode: 200)
        return (body, response)
      }
      await counter.increment()
      let body = PlaybackTestSupport.chapterListBody(assetId: assetId)
      let response = PlaybackTestSupport.response(for: request, statusCode: 200)
      return (body, response)
    }

    let client = PlaybackClient(
      baseURL: PlaybackTestSupport.aitherBaseURL,
      downstreamClient: downstream,
      cacheTTL: 60)

    _ = await client.fetchChapters(assetId: assetId, requestID: "req-1")
    let firstCount = await counter.value
    #expect(firstCount == 1)

    // FR-007: regeneration invalidates the cache.
    _ = await client.regenerate(assetId: assetId, requestID: "req-2")

    _ = await client.fetchChapters(assetId: assetId, requestID: "req-3")
    let secondCount = await counter.value
    #expect(secondCount == 2)
  }

  @Test
  func networkFailureMapsToUnauthorizedViaAuthRuntime() async throws {
    // Note: the Spec 005 AuthenticationRuntime wraps non-AuthenticationError
    // transport failures (e.g. URLError) as `serviceAuthorizationFailed`,
    // which the PlaybackClient maps to `.unauthorized`. This is a known
    // limitation of the auth runtime's error envelope; a future Spec 005
    // refinement could distinguish transport failures from auth failures.
    let runtime = try PlaybackTestSupport.makeRuntime()
    let downstream = DownstreamServiceClient(runtime: runtime) { _ in
      throw URLError(.notConnectedToInternet)
    }

    let client = PlaybackClient(
      baseURL: PlaybackTestSupport.aitherBaseURL,
      downstreamClient: downstream,
      cacheTTL: 60)

    let result = await client.fetchChapters(assetId: "rec_test", requestID: "req-1")
    let error = try #require(result.playbackError)
    #expect(error == .unauthorized)
  }

  @Test
  func invalidJSONMapsToInvalidResponse() async throws {
    let runtime = try PlaybackTestSupport.makeRuntime()
    let downstream = DownstreamServiceClient(runtime: runtime) { request in
      let body = Data("not json".utf8)
      let response = PlaybackTestSupport.response(for: request, statusCode: 200)
      return (body, response)
    }

    let client = PlaybackClient(
      baseURL: PlaybackTestSupport.aitherBaseURL,
      downstreamClient: downstream,
      cacheTTL: 60)

    let result = await client.fetchChapters(assetId: "rec_test", requestID: "req-1")
    let error = try #require(result.playbackError)
    #expect(error == .invalidResponse)
  }

  @Test
  func resolvesPlaybackURLFromRedirect() async throws {
    let runtime = try PlaybackTestSupport.makeRuntime()
    let muxURL = "https://stream.mux.com/playback-id.m3u8"
    // The mock simulates an already-followed redirect: returns 200 with the
    // redirect target as the response URL (as URLSession would after following).
    let downstream = DownstreamServiceClient(runtime: runtime) { _ in
      let redirectURL = URL(string: muxURL)!
      let httpResponse = HTTPURLResponse(
        url: redirectURL, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
      return (Data(), httpResponse)
    }

    let client = PlaybackClient(
      baseURL: PlaybackTestSupport.aitherBaseURL,
      downstreamClient: downstream,
      cacheTTL: 60)

    // Pass nil transport to use the mock's default transport (not the real URLSession).
    let result = await client.resolvePlaybackURL(
      assetId: "rec_stream_test", requestID: "req-1",
      transport: nil)
    let playbackURL = try #require(result.value)
    #expect(playbackURL.absoluteString == muxURL)
  }
}

private actor FetchCounter {
  private(set) var count = 0
  func increment() { count += 1 }
  var value: Int { count }
}
