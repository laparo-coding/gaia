import Foundation
import ObjectiveC
import Testing

/// Per-test URL protocol stub for the dashboard tests.
///
/// `makeDashboardTestSession(handler:)` allocates a fresh `URLProtocol`
/// subclass at runtime via the Objective-C runtime. The handler is stored
/// in a process-wide Swift dictionary keyed by the runtime-allocated subclass
/// (`ObjectIdentifier(type)`), so each URLSession's protocol has its own slot and
/// concurrent sessions can never clobber one another. This removes the
/// `URLError -1011` flakes that appeared when Swift Testing parallelised
/// dashboard suites against a shared static handler.
private final class ScopedDashboardURLProtocol: URLProtocol, @unchecked Sendable {
  override class func canInit(with request: URLRequest) -> Bool {
    true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    // `type(of: self)` would return the static base class; we need the
    // runtime subclass so that the per-class handler is found.
    let runtimeClass: AnyClass = object_getClass(self).map { $0 as AnyClass } ?? type(of: self)
    let key = ObjectIdentifier(runtimeClass)
    let box = ScopedDashboardURLProtocol.handlerStorage.value(for: key)
    guard let box else {
      Issue.record("Dashboard URL protocol handler is not installed on \(runtimeClass).")
      client?.urlProtocolDidFinishLoading(self)
      return
    }

    do {
      let (response, data) = try box.closure(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}

  // Storage is a Swift dictionary keyed by the `ObjectIdentifier` of each
  // runtime-allocated subclass. We mark it `@unchecked Sendable` because all
  // access is funnelled through the `storageLock` below.
  fileprivate static let handlerStorage = HandlerStorage()

  fileprivate final class HandlerStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [ObjectIdentifier: HandlerBox] = [:]

    func set(_ box: HandlerBox, for key: ObjectIdentifier) {
      lock.lock()
      storage[key] = box
      lock.unlock()
    }

    func value(for key: ObjectIdentifier) -> HandlerBox? {
      lock.lock()
      defer { lock.unlock() }
      return storage[key]
    }
  }

  fileprivate static func install(
    handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data),
    on type: AnyClass
  ) {
    handlerStorage.set(HandlerBox(handler), for: ObjectIdentifier(type))
  }

  final class HandlerBox {
    let closure: (URLRequest) throws -> (HTTPURLResponse, Data)
    init(_ closure: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) {
      self.closure = closure
    }
  }
}

private final class DashboardURLProtocolNamer: @unchecked Sendable {
  static let shared = DashboardURLProtocolNamer()

  private let lock = NSLock()
  private var counter: Int = 0

  func nextName() -> String {
    lock.lock()
    counter += 1
    let name = "DashboardTestURLProtocol_\(counter)"
    lock.unlock()
    return name
  }
}

/// Build an ephemeral `URLSession` that routes every request through a
/// per-call `URLProtocol` subclass carrying the given handler.
func makeDashboardTestSession(
  handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
) -> URLSession {
  let className = DashboardURLProtocolNamer.shared.nextName()

  guard
    let subclass = objc_allocateClassPair(
      ScopedDashboardURLProtocol.self,
      className,
      0
    )
  else {
    fatalError("Failed to allocate URLProtocol subclass \(className)")
  }

  objc_registerClassPair(subclass)
  ScopedDashboardURLProtocol.install(handler: handler, on: subclass)

  let configuration = URLSessionConfiguration.ephemeral
  let protocolClass: AnyClass = subclass
  configuration.protocolClasses = [protocolClass]
  configuration.timeoutIntervalForRequest = 0
  configuration.timeoutIntervalForResource = 0
  return URLSession(configuration: configuration)
}

/// Best-effort cleanup hook.
///
/// Note: handlers are stored in a process-wide static dictionary keyed by the
/// runtime-allocated URLProtocol subclass, so they are retained for the life of
/// the test process (Objective-C runtime classes cannot be deallocated).
func clearDashboardTestHandlers() {
  // Intentionally no-op.
}
