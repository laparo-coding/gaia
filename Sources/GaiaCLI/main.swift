import Foundation
import GaiaCore
import GaiaFeatureCatalog

enum GaiaCLIError: Error {
  case invalidUsage(String)
}

extension GaiaCLIError: LocalizedError {
  var errorDescription: String? {
    switch self {
    case let .invalidUsage(message):
      return message
    }
  }
}

struct WorkspaceSnapshot: Encodable {
  let schemaVersion: String

  struct BlueprintSnapshot: Encodable {
    let name: String
    let recommendedDirectories: [String]
    let summary: String
  }

  struct CatalogSnapshot: Encodable {
    let entries: [FeatureDescriptor]
    let nextSpecDirectory: String
    let summary: String
  }

  let blueprint: BlueprintSnapshot
  let catalog: CatalogSnapshot
}

struct NewFeatureResult: Encodable {
  let schemaVersion: String
  let mode: String
  let descriptor: FeatureDescriptor
  let targetDirectory: String
  let requestedPreviewFiles: [String]
  let requestedPreviewProfiles: [String]
  let description: String?
  let previewArtifacts: [String: String]?
  let message: String
}

struct ServiceCheckResult: Encodable {
  struct ServiceStatus: Encodable {
    let baseURL: String
    let statusCode: Int?
    let authorizationStatus: String?
    let retryOnExpiry: Bool?
    let responsePreview: String?
    let error: String?
  }

  let schemaVersion: String
  let hemera: ServiceStatus
  let aither: ServiceStatus
}

struct NewFeatureCommand {
  let slug: String
  let title: String?
  let summary: String
  let description: String?
  let dryRun: Bool
  let previewFiles: [String]
  let previewProfiles: [String]

  static let usage =
    "Usage: swift run GaiaCLI new-feature <slug> [--title|-t <title>] [--summary|-s <summary>] [--description|-d <description>] [--dry-run|-n] [--preview|-p <artifact>] [--preview-profile|-P <profile>] [--json|-j]"

  static func parse(arguments: [String]) throws -> NewFeatureCommand {
    guard arguments.count >= 2 else {
      throw FeatureCatalogError.missingSlugArgument
    }

    let slug = arguments[1]
    var title: String?
    var summary = "[TODO: replace with approved feature summary]"
    var description: String?
    var dryRun = false
    var previewFiles: [String] = []
    var previewProfiles: [String] = []
    var positionalTitleParts: [String] = []
    var index = 2

    while index < arguments.count {
      let argument = arguments[index]

      if argument == "--dry-run" || argument == "-n" {
        dryRun = true
        index += 1
        continue
      }

      if argument.hasPrefix("-") {
        guard
          [
            "--title", "-t", "--summary", "-s", "--description", "-d", "--preview", "-p",
            "--preview-profile", "-P",
          ].contains(argument)
        else {
          throw FeatureCatalogError.unknownOption(argument)
        }

        guard index + 1 < arguments.count else {
          throw FeatureCatalogError.missingOptionValue(argument)
        }

        let value = arguments[index + 1]
        switch argument {
        case "--title", "-t":
          title = value
        case "--summary", "-s":
          summary = value
        case "--description", "-d":
          description = value
        case "--preview", "-p":
          previewFiles.append(contentsOf: previewArtifacts(from: value))
        case "--preview-profile", "-P":
          previewProfiles.append(contentsOf: previewProfileNames(from: value))
        default:
          throw FeatureCatalogError.unknownOption(argument)
        }

        index += 2
        continue
      }

      positionalTitleParts.append(argument)
      index += 1
    }

    if title == nil, !positionalTitleParts.isEmpty {
      title = positionalTitleParts.joined(separator: " ")
    }

    if !previewFiles.isEmpty || !previewProfiles.isEmpty, !dryRun {
      throw GaiaCLIError.invalidUsage(
        "Preview filters require --dry-run|-n. \(usage)"
      )
    }

    let resolvedPreviewFiles = try resolvedPreviewFiles(
      requestedFiles: previewFiles,
      requestedProfiles: previewProfiles
    )

    return NewFeatureCommand(
      slug: slug,
      title: title,
      summary: summary,
      description: description,
      dryRun: dryRun,
      previewFiles: resolvedPreviewFiles,
      previewProfiles: unique(previewProfiles)
    )
  }

  private static func previewArtifacts(from rawValue: String) -> [String] {
    rawValue
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  private static func previewProfileNames(from rawValue: String) -> [String] {
    rawValue
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
      .filter { !$0.isEmpty }
  }

  private static func resolvedPreviewFiles(
    requestedFiles: [String],
    requestedProfiles: [String]
  ) throws -> [String] {
    var combined = requestedFiles

    for profile in requestedProfiles {
      combined.append(contentsOf: try FeatureScaffold.artifacts(forProfile: profile))
    }

    return unique(combined)
  }

  private static func unique(_ values: [String]) -> [String] {
    var seen: Set<String> = []
    var result: [String] = []

    for value in values where seen.insert(value).inserted {
      result.append(value)
    }

    return result
  }
}

struct ServiceCheckCommand {
  let hemeraBaseURL: URL
  let aitherBaseURL: URL

  static let usage =
    "Usage: swift run GaiaCLI service-check [--hemera-base-url <url>] [--aither-base-url <url>] [--json|-j]"

  static func parse(arguments: [String]) throws -> ServiceCheckCommand {
    guard let defaultHemeraBaseURL = URL(string: "http://127.0.0.1:3000") else {
      throw GaiaCLIError.invalidUsage(usage)
    }
    guard let defaultAitherBaseURL = URL(string: "http://127.0.0.1:3500") else {
      throw GaiaCLIError.invalidUsage(usage)
    }

    var hemeraBaseURL = defaultHemeraBaseURL
    var aitherBaseURL = defaultAitherBaseURL
    var index = 1

    while index < arguments.count {
      let argument = arguments[index]
      guard argument.hasPrefix("--"), index + 1 < arguments.count else {
        throw GaiaCLIError.invalidUsage(usage)
      }

      let value = arguments[index + 1]
      switch argument {
      case "--hemera-base-url":
        guard let url = URL(string: value) else {
          throw GaiaCLIError.invalidUsage(usage)
        }
        hemeraBaseURL = url
      case "--aither-base-url":
        guard let url = URL(string: value) else {
          throw GaiaCLIError.invalidUsage(usage)
        }
        aitherBaseURL = url
      default:
        throw GaiaCLIError.invalidUsage(usage)
      }

      index += 2
    }

    return ServiceCheckCommand(
      hemeraBaseURL: hemeraBaseURL,
      aitherBaseURL: aitherBaseURL
    )
  }
}

let outputSchemaVersion = "1.0"

func resolvedServiceToken(
  environment: [String: String],
  primaryKey: String,
  fallbackKey: String?
) -> String? {
  if let value = environment[primaryKey], !value.isEmpty {
    return value
  }

  if let fallbackKey, let value = environment[fallbackKey], !value.isEmpty {
    return value
  }

  return nil
}

func makeServiceCheckRuntime(environment: [String: String]) throws -> AuthenticationRuntime {
  let cacheStore = ServiceTokenCacheStore()
  let telemetry = AuthenticationTelemetry()
  let sessionManager = AuthenticationSessionManager()
  guard let authenticationBaseURL = URL(string: "http://127.0.0.1:8080") else {
    throw GaiaCLIError.invalidUsage(ServiceCheckCommand.usage)
  }
  let interactiveProvider = StaticInteractiveAuthenticationProvider(
    authenticationBaseURL: authenticationBaseURL
  )

  let hemeraCredential = try ServiceCredential(
    service: .hemera,
    envPrimaryKey: "HEMERA_SERVICE_API_KEY",
    envFallbackKey: "HEMERA_SERVICE_TOKEN",
    cacheKey: "service.hemera",
    tokenType: .bearer,
    audience: "hemera",
    refreshLeewaySeconds: 60
  )
  let aitherCredential = try ServiceCredential(
    service: .aither,
    envPrimaryKey: "AITHER_SYNC_TOKEN",
    envFallbackKey: "AITHER_SERVICE_TOKEN",
    cacheKey: "service.aither",
    tokenType: .bearer,
    audience: "aither",
    refreshLeewaySeconds: 60
  )

  let hemeraAuthenticator = HemeraServiceAuthenticator(
    credential: hemeraCredential,
    cacheStore: cacheStore
  ) { _ in
    guard
      let token = resolvedServiceToken(
        environment: environment,
        primaryKey: "HEMERA_SERVICE_API_KEY",
        fallbackKey: "HEMERA_SERVICE_TOKEN"
      )
    else {
      throw AuthenticationError.serviceAuthorizationFailed(service: .hemera)
    }

    let now = Date()
    return LoadedServiceToken(
      token: token,
      expiresAt: now.addingTimeInterval(3600),
      refreshedAt: now
    )
  }

  let aitherAuthenticator = AitherServiceAuthenticator(
    credential: aitherCredential,
    cacheStore: cacheStore
  ) { _ in
    guard
      let token = resolvedServiceToken(
        environment: environment,
        primaryKey: "AITHER_SYNC_TOKEN",
        fallbackKey: "AITHER_SERVICE_TOKEN"
      )
    else {
      throw AuthenticationError.serviceAuthorizationFailed(service: .aither)
    }

    let now = Date()
    return LoadedServiceToken(
      token: token,
      expiresAt: now.addingTimeInterval(3600),
      refreshedAt: now
    )
  }

  return AuthenticationRuntime(
    sessionManager: sessionManager,
    interactiveProvider: interactiveProvider,
    serviceCoordinator: ServiceAuthorizationCoordinator(
      cacheStore: cacheStore,
      hemeraAuthenticator: hemeraAuthenticator,
      aitherAuthenticator: aitherAuthenticator,
      telemetry: telemetry
    )
  )
}

func responsePreview(_ data: Data?) -> String? {
  guard let data, !data.isEmpty else {
    return nil
  }

  let text = String(decoding: data.prefix(200), as: UTF8.self)
  return text.isEmpty ? nil : text
}

func makeServiceStatus(
  baseURL: URL,
  result: AuthorizedRequestResult<DownstreamServiceResponse>
) -> ServiceCheckResult.ServiceStatus {
  ServiceCheckResult.ServiceStatus(
    baseURL: baseURL.absoluteString,
    statusCode: result.value?.statusCode,
    authorizationStatus: result.authorization?.status.rawValue,
    retryOnExpiry: result.authorization?.retryOnExpiry,
    responsePreview: responsePreview(result.value?.body),
    error: result.error.map { String(describing: $0) }
  )
}

func runServiceCheck(command: ServiceCheckCommand) async throws -> ServiceCheckResult {
  let runtime = try makeServiceCheckRuntime(environment: environment)
  let client = DownstreamServiceClient(runtime: runtime)
  let now = Date()

  let hemeraResult = await client.send(
    service: .hemera,
    baseURL: command.hemeraBaseURL,
    path: "/api/service/courses",
    method: "GET",
    operation: "read-courses",
    requestId: "gaia-hemera-check",
    now: now
  )

  let aitherResult = await client.send(
    service: .aither,
    baseURL: command.aitherBaseURL,
    path: "/api/sync",
    method: "POST",
    operation: "trigger-sync",
    requestId: "gaia-aither-check",
    now: now
  )

  return ServiceCheckResult(
    schemaVersion: outputSchemaVersion,
    hemera: makeServiceStatus(baseURL: command.hemeraBaseURL, result: hemeraResult),
    aither: makeServiceStatus(baseURL: command.aitherBaseURL, result: aitherResult)
  )
}

func printJSON<Value: Encodable>(_ value: Value) throws {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  let data = try encoder.encode(value)
  guard let string = String(data: data, encoding: .utf8) else {
    throw GaiaCLIError.invalidUsage("Failed to encode JSON output.")
  }

  print(string)
}

let blueprint = ProjectBlueprint()
let fileManager = FileManager.default
let repositoryRoot = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
let specsDirectory = repositoryRoot.appendingPathComponent("specs", isDirectory: true)
let environment = LocalEnvironment.mergedWithProcessEnvironment(
  currentDirectoryPath: fileManager.currentDirectoryPath,
  processEnvironment: ProcessInfo.processInfo.environment
)
let _ = RollbarBootstrap.initialize(
  environment: environment,
  appName: "GaiaCLI"
)
let rawArguments = Array(CommandLine.arguments.dropFirst())
let jsonOutput = rawArguments.contains("--json") || rawArguments.contains("-j")
let arguments = rawArguments.filter { $0 != "--json" && $0 != "-j" }

do {
  switch arguments.first {
  case nil:
    let catalog = try FeatureCatalog.discover(
      in: specsDirectory,
      blueprint: blueprint,
      fileManager: fileManager
    )

    if jsonOutput {
      try printJSON(
        WorkspaceSnapshot(
          schemaVersion: outputSchemaVersion,
          blueprint: .init(
            name: blueprint.name,
            recommendedDirectories: blueprint.recommendedDirectories(),
            summary: blueprint.summary()
          ),
          catalog: .init(
            entries: catalog.features,
            nextSpecDirectory: catalog.nextSpecDirectory(),
            summary: catalog.summary()
          )
        )
      )
    } else {
      print(blueprint.summary())
      print(catalog.summary())
    }
  case "new-feature":
    let catalog = try FeatureCatalog.discover(
      in: specsDirectory,
      blueprint: blueprint,
      fileManager: fileManager
    )

    let command = try NewFeatureCommand.parse(arguments: arguments)

    if command.dryRun {
      let scaffold = try catalog.preparedScaffold(
        slug: command.slug,
        title: command.title,
        summary: command.summary,
        description: command.description
      )
      let selectedArtifacts = try scaffold.selectedArtifacts(named: command.previewFiles)

      if jsonOutput {
        let previewArtifacts = Dictionary(
          uniqueKeysWithValues: selectedArtifacts.map { ($0.name, $0.content) })
        try printJSON(
          NewFeatureResult(
            schemaVersion: outputSchemaVersion,
            mode: "dry-run",
            descriptor: scaffold.descriptor,
            targetDirectory: scaffold.descriptor.specDirectory,
            requestedPreviewFiles: command.previewFiles,
            requestedPreviewProfiles: command.previewProfiles,
            description: command.description,
            previewArtifacts: previewArtifacts,
            message: "Dry run prepared for \(scaffold.descriptor.specDirectory)"
          )
        )
      } else {
        print("Dry run for \(scaffold.descriptor.specDirectory)")
        print("Would create: spec.md, plan.md, tasks.md")
        print("Title: \(scaffold.descriptor.title)")
        print("Summary: \(scaffold.descriptor.summary)")
        if let description = command.description {
          print("Description: \(description)")
        }
        if !command.previewFiles.isEmpty {
          print("Previewing: \(command.previewFiles.joined(separator: ", "))")
        }
        if !command.previewProfiles.isEmpty {
          print("Profiles: \(command.previewProfiles.joined(separator: ", "))")
        }
        for artifact in selectedArtifacts {
          print("--- \(artifact.name) ---")
          print(artifact.content)
        }
      }
    } else {
      let descriptor = try catalog.scaffoldNextFeature(
        slug: command.slug,
        title: command.title,
        summary: command.summary,
        description: command.description,
        in: repositoryRoot,
        fileManager: fileManager
      )

      if jsonOutput {
        try printJSON(
          NewFeatureResult(
            schemaVersion: outputSchemaVersion,
            mode: "created",
            descriptor: descriptor,
            targetDirectory: descriptor.specDirectory,
            requestedPreviewFiles: [],
            requestedPreviewProfiles: [],
            description: command.description,
            previewArtifacts: nil,
            message: "Created feature scaffold at \(descriptor.specDirectory)"
          )
        )
      } else {
        print("Created feature scaffold at \(descriptor.specDirectory)")
        print("Next step: fill out \(descriptor.specDirectory)/spec.md before implementation.")
      }
    }
  case "service-check":
    let command = try ServiceCheckCommand.parse(arguments: arguments)
    let result = try await runServiceCheck(command: command)

    if jsonOutput {
      try printJSON(result)
    } else {
      print(
        "Hemera: \(result.hemera.statusCode.map(String.init) ?? "n/a") [\(result.hemera.authorizationStatus ?? "unknown")] @ \(result.hemera.baseURL)"
      )
      print(
        "Aither: \(result.aither.statusCode.map(String.init) ?? "n/a") [\(result.aither.authorizationStatus ?? "unknown")] @ \(result.aither.baseURL)"
      )

      if let error = result.hemera.error {
        print("Hemera error: \(error)")
      }
      if let error = result.aither.error {
        print("Aither error: \(error)")
      }
    }
  default:
    throw GaiaCLIError.invalidUsage(
      "Unknown command. Use `swift run GaiaCLI [--json|-j]`, \(NewFeatureCommand.usage), or \(ServiceCheckCommand.usage)"
    )
  }
} catch {
  FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
  Foundation.exit(1)
}
