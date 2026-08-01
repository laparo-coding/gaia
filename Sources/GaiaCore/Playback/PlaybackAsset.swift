import Foundation

/// Resolved playback target for the MUX player (Spec 010, research R2).
///
/// The `playbackURL` is obtained by following the HTTP 302 redirect from
/// Aither's `GET /api/recording/stream/[id]` endpoint to the MUX CDN URL.
public struct PlaybackAsset: Equatable, Sendable {
  public let assetId: String
  public let playbackURL: URL

  public init(assetId: String, playbackURL: URL) {
    self.assetId = assetId
    self.playbackURL = playbackURL
  }
}
