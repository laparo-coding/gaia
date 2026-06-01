import Foundation
import RollbarNotifier

// Intentional benign race: gaiaDrainRollbarAtExit reads exitDrainInterval lock-free because atexit
// runs during process teardown. registerExitDrainIfNeeded serializes all writes under lock,
// and initialize gates repeated registration via isInitialized / didRegisterExitDrain.
private func gaiaDrainRollbarAtExit() {
  let interval = RollbarBootstrap.exitDrainInterval
  guard interval > 0 else {
    return
  }

  Thread.sleep(forTimeInterval: interval)
}

private func gaiaWriteRollbarDiagnostic(_ message: String) {
  FileHandle.standardError.write(Data("\(message)\n".utf8))
}

public enum RollbarBootstrap {
  struct AccessTokenConfiguration: Equatable {
    let source: String
    let value: String
  }

  enum RuntimeEnvironment: String {
    case development
    case test
    case production
  }

  private static let lock = NSLock()
  private nonisolated(unsafe) static var isInitialized = false
  private nonisolated(unsafe) static var didRegisterExitDrain = false
  nonisolated(unsafe) static var exitDrainInterval: TimeInterval = 0

  public static func initialize(environment: [String: String], appName: String) -> Bool {
    lock.lock()
    defer { lock.unlock() }

    guard !isInitialized else {
      return true
    }

    let runtimeEnvironment = resolvedRuntimeEnvironment(from: environment)
    let diagnosticsEnabled = shouldEmitDiagnostics(
      for: runtimeEnvironment,
      environment: environment
    )

    guard let accessTokenConfiguration = resolvedAccessTokenConfiguration(from: environment) else {
      if diagnosticsEnabled {
        gaiaWriteRollbarDiagnostic(
          missingTokenDiagnosticMessage(appName: appName, environment: runtimeEnvironment)
        )
      }
      return false
    }

    let configuration = RollbarConfig.mutableConfig(
      withAccessToken: accessTokenConfiguration.value,
      environment: runtimeEnvironment.rawValue
    )
    Rollbar.initWithConfiguration(configuration)
    let drainInterval = resolvedDeliveryDrainInterval(from: environment)
    registerExitDrainIfNeeded(delay: drainInterval)

    if diagnosticsEnabled {
      gaiaWriteRollbarDiagnostic(
        activeDiagnosticMessage(
          appName: appName,
          environment: runtimeEnvironment,
          drainInterval: drainInterval,
          accessTokenConfiguration: accessTokenConfiguration
        )
      )
    }

    if shouldSendStartupMessage(for: runtimeEnvironment) {
      Rollbar.infoMessage(startupMessage(appName: appName, environment: runtimeEnvironment))
    }

    isInitialized = true
    return true
  }

  static func resolvedAccessToken(from environment: [String: String]) -> String? {
    resolvedAccessTokenConfiguration(from: environment)?.value
  }

  static func resolvedAccessTokenConfiguration(
    from environment: [String: String]
  ) -> AccessTokenConfiguration? {
    for key in ["GAIA_ROLLBAR_ACCESS_TOKEN", "ROLLBAR_ACCESS_TOKEN"] {
      if let value = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
        !value.isEmpty
      {
        return AccessTokenConfiguration(source: key, value: value)
      }
    }

    return nil
  }

  static func resolvedRuntimeEnvironment(from environment: [String: String]) -> RuntimeEnvironment {
    if environment["XCTestConfigurationFilePath"] != nil || environment["GAIA_TEST"] == "1" {
      return .test
    }

    for key in ["GAIA_ENV", "ROLLBAR_ENVIRONMENT", "ENVIRONMENT"] {
      guard
        let value = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines)
          .lowercased(), !value.isEmpty
      else {
        continue
      }

      switch value {
      case "test", "testing":
        return .test
      case "dev", "development", "local":
        return .development
      case "prod", "production":
        return .production
      default:
        continue
      }
    }

    #if DEBUG
      return .development
    #else
      return .production
    #endif
  }

  static func shouldSendStartupMessage(for environment: RuntimeEnvironment) -> Bool {
    environment == .development || environment == .test
  }

  static func startupMessage(appName: String, environment: RuntimeEnvironment) -> String {
    "\(appName) Rollbar initialisiert (Environment: \(environment.rawValue))."
  }

  static func shouldEmitDiagnostics(
    for runtimeEnvironment: RuntimeEnvironment,
    environment: [String: String]
  ) -> Bool {
    for key in ["GAIA_ROLLBAR_DIAGNOSTICS", "ROLLBAR_DIAGNOSTICS"] {
      guard
        let value = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines)
          .lowercased(), !value.isEmpty
      else {
        continue
      }

      switch value {
      case "0", "false", "no", "off":
        return false
      case "1", "true", "yes", "on":
        return true
      default:
        continue
      }
    }

    return runtimeEnvironment == .development || runtimeEnvironment == .test
  }

  static func missingTokenDiagnosticMessage(
    appName: String,
    environment: RuntimeEnvironment
  ) -> String {
    "[Rollbar] deaktiviert fuer \(appName) (environment: \(environment.rawValue)): kein GAIA_ROLLBAR_ACCESS_TOKEN oder ROLLBAR_ACCESS_TOKEN gesetzt."
  }

  static func activeDiagnosticMessage(
    appName: String,
    environment: RuntimeEnvironment,
    drainInterval: TimeInterval,
    accessTokenConfiguration: AccessTokenConfiguration
  ) -> String {
    "[Rollbar] aktiv fuer \(appName) (environment: \(environment.rawValue), drain: \(drainInterval)s, token source: \(accessTokenConfiguration.source), token length: \(accessTokenConfiguration.value.count))."
  }

  static func resolvedDeliveryDrainInterval(from environment: [String: String]) -> TimeInterval {
    for key in ["GAIA_ROLLBAR_DELIVERY_WAIT_SECONDS", "ROLLBAR_DELIVERY_WAIT_SECONDS"] {
      guard let rawValue = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
        !rawValue.isEmpty
      else {
        continue
      }

      if let parsedValue = TimeInterval(rawValue) {
        return max(0, parsedValue)
      }
    }

    return 1.0
  }

  private static func registerExitDrainIfNeeded(delay: TimeInterval) {
    guard !didRegisterExitDrain else {
      // initialize returns early once isInitialized is true, so this max(...) path is
      // effectively unreachable in normal flow; it remains as a defensive fallback.
      exitDrainInterval = max(exitDrainInterval, delay)
      return
    }

    exitDrainInterval = delay
    atexit(gaiaDrainRollbarAtExit)
    didRegisterExitDrain = true
  }
}
