import Foundation
import Testing

@testable import GaiaCore

@Suite(.serialized)
struct ConnectionStatusMonitorTests {
  @Test
  func loadBootstrapSnapshotMapsConnectionAndSystemHealth() async throws {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let session = makeDashboardTestSession { request in
      let response = HTTPURLResponse(
        url: request.url ?? URL(string: "http://localhost:8080/api/dashboard/status")!,
        statusCode: 200,
        httpVersion: "HTTP/1.1",
        headerFields: ["Content-Type": "application/json"]
      )!
      let body = """
        {
          "connection": { "aither": "connected", "hemera": "disconnected" },
          "system": { "serviceStatus": "degraded", "lastUpdatedAt": "\(ISO8601DateFormatter().string(from: now))" },
          "events": { "transport": "sse", "endpoint": "/api/dashboard/status/events" }
        }
        """
      return (response, Data(body.utf8))
    }

    let monitor = ConnectionStatusMonitor(
      baseURL: URL(string: "http://localhost:8080")!, session: session)
    let snapshot = try await monitor.loadBootstrapSnapshot(courseID: "course-xyz")

    #expect(snapshot.course.id == "course-xyz")
    #expect(snapshot.connection.aither == .connected)
    #expect(snapshot.connection.hemera == .disconnected)
    #expect(snapshot.system.serviceStatus == .degraded)
  }

  @Test
  func eventStreamDecodesSSEPayload() async throws {
    let now = Date(timeIntervalSince1970: 1_700_000_001)
    let monitor = ConnectionStatusMonitor(
      baseURL: URL(string: "http://localhost:8080")!,
      session: makeDashboardTestSession { _ in
        (HTTPURLResponse(), Data())
      }
    )

    let firstFrame = """
      data: {"type":"connection.changed","timestamp":"\(ISO8601DateFormatter().string(from: now))","connection":{"aither":"connected","hemera":"connecting"},"system":{"serviceStatus":"healthy","lastUpdatedAt":"\(ISO8601DateFormatter().string(from: now))"}}

      """

    let secondFrame = """
      data: {"type":"connection.changed","timestamp":"\(ISO8601DateFormatter().string(from: now))","connection":{"aither":"connected","hemera":"connected"},"system":{"serviceStatus":"healthy","lastUpdatedAt":"\(ISO8601DateFormatter().string(from: now))"}}

      """

    let combined = firstFrame + "\n" + secondFrame
    let events = monitor.decodeSSEEvents(from: Data(combined.utf8))

    #expect(events.count == 2)
    #expect(events.first?.type == .connectionChanged)
    #expect(events.first?.connection.hemera == .connecting)
    #expect(events.last?.connection.hemera == .connected)
  }

  @Test
  func eventStreamIgnoresHeartbeatAndComments() async throws {
    let monitor = ConnectionStatusMonitor(
      baseURL: URL(string: "http://localhost:8080")!,
      session: makeDashboardTestSession { _ in
        (HTTPURLResponse(), Data())
      }
    )

    let now = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: 1_700_000_002))
    let payload = """
      : heartbeat \(now)

      data: {"type":"system.changed","timestamp":"\(now)","connection":{"aither":"connected","hemera":"connected"},"system":{"serviceStatus":"healthy","lastUpdatedAt":"\(now)"}}

      """

    let events = monitor.decodeSSEEvents(from: Data(payload.utf8))

    #expect(events.count == 1)
    #expect(events.first?.type == .systemChanged)
  }

  @Test
  func statusEventRequestTargetsEventsEndpointWithSSEHeaders() {
    let monitor = ConnectionStatusMonitor(
      baseURL: URL(string: "http://localhost:8080")!,
      session: makeDashboardTestSession { _ in
        (HTTPURLResponse(), Data())
      },
      eventsEndpointPath: "/api/dashboard/status/events"
    )

    let request = monitor.makeStatusEventRequest()

    #expect(request.httpMethod == "GET")
    #expect(request.url?.path == "/api/dashboard/status/events")
    #expect(request.value(forHTTPHeaderField: "Accept") == "text/event-stream")
    #expect(request.value(forHTTPHeaderField: "Cache-Control") == "no-cache")
  }

  @Test
  func eventStreamFinishesCleanlyWhenServerClosesStream() async throws {
    let now = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: 1_700_000_010))
    let frame =
      "data: {\"type\":\"connection.changed\",\"timestamp\":\"\(now)\",\"connection\":{\"aither\":\"connected\",\"hemera\":\"connected\"},\"system\":{\"serviceStatus\":\"healthy\",\"lastUpdatedAt\":\"\(now)\"}}\n\n"

    let session = makeDashboardTestSession { request in
      let response = HTTPURLResponse(
        url: request.url ?? URL(string: "http://localhost:8080/api/dashboard/status/events")!,
        statusCode: 200,
        httpVersion: "HTTP/1.1",
        headerFields: ["Content-Type": "text/event-stream"]
      )!
      return (response, Data(frame.utf8))
    }

    let monitor = ConnectionStatusMonitor(
      baseURL: URL(string: "http://localhost:8080")!,
      session: session,
      reconnectBackoff: [0.001, 0.001, 0.001]
    )

    var iterator = monitor.eventStream().makeAsyncIterator()
    let first = try await iterator.next()
    #expect(first != nil)
    let second = try await iterator.next()
    #expect(second == nil)
  }

  @Test
  func eventStreamSurfacesErrorAfterReconnectBudgetExhausted() async throws {
    let session = makeDashboardTestSession { _ in
      throw URLError(.notConnectedToInternet)
    }

    let monitor = ConnectionStatusMonitor(
      baseURL: URL(string: "http://localhost:8080")!,
      session: session,
      reconnectBackoff: [0.001, 0.001]
    )

    var iterator = monitor.eventStream().makeAsyncIterator()
    do {
      while let _ = try await iterator.next() {
        // Stream yields nothing because URL errors propagate through finish.
      }
    } catch {
      // Expected: the URL error should surface after the backoff budget is exhausted.
      #expect(error is URLError)
    }
  }

  @Test
  func eventStreamCancellationTerminatesPromptly() async throws {
    let now = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: 1_700_000_011))
    let frame =
      "data: {\"type\":\"connection.changed\",\"timestamp\":\"\(now)\",\"connection\":{\"aither\":\"connected\",\"hemera\":\"connected\"},\"system\":{\"serviceStatus\":\"healthy\",\"lastUpdatedAt\":\"\(now)\"}}\n\n"

    let session = makeDashboardTestSession { request in
      let response = HTTPURLResponse(
        url: request.url ?? URL(string: "http://localhost:8080/api/dashboard/status/events")!,
        statusCode: 200,
        httpVersion: "HTTP/1.1",
        headerFields: ["Content-Type": "text/event-stream"]
      )!
      return (response, Data(frame.utf8))
    }

    let monitor = ConnectionStatusMonitor(
      baseURL: URL(string: "http://localhost:8080")!,
      session: session,
      reconnectBackoff: [0.001, 0.001, 0.001]
    )

    let stream = monitor.eventStream()
    let cancellationTask = Task {
      var iterator = stream.makeAsyncIterator()
      _ = try? await iterator.next()
      iterator = stream.makeAsyncIterator()
      _ = try? await iterator.next()
    }
    cancellationTask.cancel()
    await cancellationTask.value
  }

}
