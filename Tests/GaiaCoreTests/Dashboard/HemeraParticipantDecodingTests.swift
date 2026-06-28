import Foundation
import Testing

@testable import GaiaCore

// MARK: - Reusable envelope types (mirrors DashboardRouteHandlers private types)

private struct HemeraCourseDetailEnvelope: Decodable {
  struct CourseDetail: Decodable {
    /// Backward-compatible participant decoding — mirrors
    /// `DashboardRouteHandlers.HemeraCourseDetailEnvelope.Participant`.
    struct Participant: Decodable {
      let userId: String
      let name: String
      let imageUrl: String?

      private enum CanonicalCodingKeys: String, CodingKey {
        case userId = "id"
        case name = "displayName"
        case imageUrl = "avatarUrl"
      }

      enum CodingKeys: String, CodingKey {
        case userId
        case name
        case imageUrl
      }

      init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let canonical = try? decoder.container(keyedBy: CanonicalCodingKeys.self)

        // Canonical (contract) keys take precedence; fall back to legacy Hemera keys.
        // Both id/userId and displayName/name are required — throw when absent.
        let resolvedUserId =
          try canonical?.decodeIfPresent(String.self, forKey: .userId)
          ?? container.decodeIfPresent(String.self, forKey: .userId)
        let resolvedName =
          try canonical?.decodeIfPresent(String.self, forKey: .name)
          ?? container.decodeIfPresent(String.self, forKey: .name)

        guard let userId = resolvedUserId, let name = resolvedName else {
          throw DecodingError.dataCorrupted(
            .init(
              codingPath: decoder.codingPath,
              debugDescription: "Participant 'id'/'userId' and 'displayName'/'name' are required"
            )
          )
        }

        self.userId = userId
        self.name = name
        self.imageUrl =
          try canonical?.decodeIfPresent(String.self, forKey: .imageUrl)
          ?? container.decodeIfPresent(String.self, forKey: .imageUrl)
      }
    }

    let id: String
    let title: String
    let participants: [Participant]
  }

  let data: CourseDetail
}

@Suite("Hemera Participant Field-Name Decoding (Backward-Compatible)")
struct HemeraParticipantDecodingTests {

  // MARK: - Legacy Hemera format (userId / name / imageUrl)

  @Test("decodes legacy Hemera participant fields correctly")
  func decodesLegacyFormat() throws {
    let json = Data(
      """
      {
        "data": {
          "id": "course-legacy",
          "title": "Legacy Course",
          "participants": [
            { "userId": "user-legacy-1", "name": "Legacy Person One", "imageUrl": "https://example.com/1.png" },
            { "userId": "user-legacy-2", "name": "Legacy Person Two", "imageUrl": null }
          ]
        }
      }
      """.utf8)

    let decoder = JSONDecoder()
    let envelope = try decoder.decode(HemeraCourseDetailEnvelope.self, from: json)

    #expect(envelope.data.id == "course-legacy")
    #expect(envelope.data.title == "Legacy Course")
    #expect(envelope.data.participants.count == 2)

    #expect(envelope.data.participants[0].userId == "user-legacy-1")
    #expect(envelope.data.participants[0].name == "Legacy Person One")
    #expect(envelope.data.participants[0].imageUrl == "https://example.com/1.png")

    #expect(envelope.data.participants[1].userId == "user-legacy-2")
    #expect(envelope.data.participants[1].name == "Legacy Person Two")
    #expect(envelope.data.participants[1].imageUrl == nil)
  }

  // MARK: - Canonical Gaia contract format (id / displayName / avatarUrl)

  @Test("decodes canonical Gaia participant fields correctly")
  func decodesCanonicalFormat() throws {
    let json = Data(
      """
      {
        "data": {
          "id": "course-canonical",
          "title": "Canonical Course",
          "participants": [
            { "id": "user-canon-1", "displayName": "Canonical Person One", "avatarUrl": "https://example.com/c1.png" },
            { "id": "user-canon-2", "displayName": "Canonical Person Two", "avatarUrl": null }
          ]
        }
      }
      """.utf8)

    let decoder = JSONDecoder()
    let envelope = try decoder.decode(HemeraCourseDetailEnvelope.self, from: json)

    #expect(envelope.data.id == "course-canonical")
    #expect(envelope.data.title == "Canonical Course")
    #expect(envelope.data.participants.count == 2)

    #expect(envelope.data.participants[0].userId == "user-canon-1")
    #expect(envelope.data.participants[0].name == "Canonical Person One")
    #expect(envelope.data.participants[0].imageUrl == "https://example.com/c1.png")

    #expect(envelope.data.participants[1].userId == "user-canon-2")
    #expect(envelope.data.participants[1].name == "Canonical Person Two")
    #expect(envelope.data.participants[1].imageUrl == nil)
  }

  // MARK: - Mixed format (both key sets present) → canonical wins

  @Test("canonical keys take precedence when both legacy and canonical keys are present")
  func canonicalKeysTakePrecedence() throws {
    let json = Data(
      """
      {
        "data": {
          "id": "course-mixed",
          "title": "Mixed Course",
          "participants": [
            {
              "id": "canon-id",
              "userId": "legacy-id",
              "displayName": "Canon Name",
              "name": "Legacy Name",
              "avatarUrl": "https://canon.url",
              "imageUrl": "https://legacy.url"
            }
          ]
        }
      }
      """.utf8)

    let decoder = JSONDecoder()
    let envelope = try decoder.decode(HemeraCourseDetailEnvelope.self, from: json)

    #expect(envelope.data.participants.count == 1)
    // Canonical keys must win
    #expect(envelope.data.participants[0].userId == "canon-id")
    #expect(envelope.data.participants[0].name == "Canon Name")
    #expect(envelope.data.participants[0].imageUrl == "https://canon.url")
  }

  // MARK: - Missing optional fields

  @Test("handles missing optional imageUrl gracefully in both formats")
  func handlesMissingOptionalFields() throws {
    let json = Data(
      """
      {
        "data": {
          "id": "course-minimal",
          "title": "Minimal",
          "participants": [
            { "userId": "u1", "name": "Only Legacy" },
            { "id": "u2", "displayName": "Only Canonical" }
          ]
        }
      }
      """.utf8)

    let decoder = JSONDecoder()
    let envelope = try decoder.decode(HemeraCourseDetailEnvelope.self, from: json)

    #expect(envelope.data.participants.count == 2)
    #expect(envelope.data.participants[0].userId == "u1")
    #expect(envelope.data.participants[0].name == "Only Legacy")
    #expect(envelope.data.participants[0].imageUrl == nil)

    #expect(envelope.data.participants[1].userId == "u2")
    #expect(envelope.data.participants[1].name == "Only Canonical")
    #expect(envelope.data.participants[1].imageUrl == nil)
  }

  // MARK: - Missing required fields → throws

  @Test func throwsWhenBothUserIdAndIdAreMissing() throws {
    let json = Data(
      """
      {
        "data": {
          "id": "course-bad",
          "title": "Bad Course",
          "participants": [
            { "name": "No ID" }
          ]
        }
      }
      """.utf8)

    let decoder = JSONDecoder()
    #expect(throws: DecodingError.self) {
      _ = try decoder.decode(HemeraCourseDetailEnvelope.self, from: json)
    }
  }

  @Test func throwsWhenBothNameAndDisplayNameAreMissing() throws {
    let json = Data(
      """
      {
        "data": {
          "id": "course-bad2",
          "title": "Bad Course 2",
          "participants": [
            { "userId": "u-no-name" }
          ]
        }
      }
      """.utf8)

    let decoder = JSONDecoder()
    #expect(throws: DecodingError.self) {
      _ = try decoder.decode(HemeraCourseDetailEnvelope.self, from: json)
    }
  }

  @Test func throwsWhenParticipantHasNoFieldsAtAll() throws {
    let json = Data(
      """
      {
        "data": {
          "id": "course-empty-p",
          "title": "Empty Participant",
          "participants": [
            {}
          ]
        }
      }
      """.utf8)

    let decoder = JSONDecoder()
    #expect(throws: DecodingError.self) {
      _ = try decoder.decode(HemeraCourseDetailEnvelope.self, from: json)
    }
  }
}
