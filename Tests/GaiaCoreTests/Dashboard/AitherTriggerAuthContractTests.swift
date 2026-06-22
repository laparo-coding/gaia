import Foundation
import Testing

@testable import GaiaCore

/// Contract test (Spec 009, FR-004): the Aither slide/presentation trigger
/// routes through the Spec 005 auth stack and carries `Authorization: Bearer`
/// (and never an `X-API-Key`). Aither is used only for triggers, not card data.
@Suite(.serialized)
struct AitherTriggerAuthContractTests {
  @Test
  func aitherTriggerCarriesBearerAuthorization() async throws {
    let runtime = try RealDataTestSupport.makeRuntime(aitherToken: "aither-test-token")

    let observed = AitherHeaderRecorder()
    let downstream = DownstreamServiceClient(runtime: runtime) { request in
      await observed.record(
        authorization: request.value(forHTTPHeaderField: "Authorization"),
        apiKey: request.value(forHTTPHeaderField: "X-API-Key"),
        method: request.httpMethod
      )
      let response = HTTPURLResponse(
        url: request.url!, statusCode: 202, httpVersion: nil,
        headerFields: ["Content-Type": "application/json"])!
      return (Data("{\"accepted\":true}".utf8), response)
    }

    let trigger = AitherPresentationTrigger(
      baseURL: RealDataTestSupport.aitherBaseURL,
      downstreamClient: downstream
    )

    let accepted = await trigger.advance(
      courseID: "course-123", requestID: "req-trigger", now: RealDataTestSupport.now)

    #expect(accepted)
    #expect(await observed.authorization == "Bearer aither-test-token")
    #expect(await observed.apiKey == nil)
    #expect(await observed.method == "POST")
  }
}

private actor AitherHeaderRecorder {
  private(set) var authorization: String?
  private(set) var apiKey: String?
  private(set) var method: String?

  func record(authorization: String?, apiKey: String?, method: String?) {
    self.authorization = authorization
    self.apiKey = apiKey
    self.method = method
  }
}
