import Foundation

/// HTTP/1.1 chunked transfer encoding helpers used by the SSE pump.
///
/// Each `encodeChunk(_:)` call produces a single chunk frame:
/// `<hex size>\r\n<bytes>\r\n`. `terminator()` yields the closing chunk
/// `0\r\n\r\n` required to end a chunked body cleanly.
public enum HTTPChunkedTransfer {
  public static func encodeChunk(_ payload: Data) -> Data {
    var chunk = Data()
    chunk.reserveCapacity(payload.count + 8)
    appendHex(payload.count, into: &chunk)
    chunk.append(contentsOf: [0x0D, 0x0A])
    chunk.append(payload)
    chunk.append(contentsOf: [0x0D, 0x0A])
    return chunk
  }

  public static func encodeChunk(_ string: String) -> Data {
    encodeChunk(Data(string.utf8))
  }

  public static func terminator() -> Data {
    Data("0\r\n\r\n".utf8)
  }

  /// Result of decoding a chunked HTTP/1.1 body stream.
  public struct DecodedChunk: Equatable, Sendable {
    public let bytes: Data
    public let isTerminal: Bool
  }

  /// State machine for chunked HTTP/1.1 decoding that mirrors RFC 7230 §4.1.
  public final class Decoder {
    public enum State: Equatable {
      case expectingSize
      case expectingData(remaining: Int)
      case expectingTrailer
      case finished
    }

    public private(set) var state: State = .expectingSize
    private var buffer = Data()

    public init() {}

    /// Appends new bytes received from the wire and returns every chunk that
    /// has been completely decoded so far. The terminal chunk (`size == 0`)
    /// is reported with `isTerminal == true` exactly once.
    public func consume(_ data: Data) -> [DecodedChunk] {
      buffer.append(data)
      var emitted: [DecodedChunk] = []

      while true {
        switch state {
        case .expectingSize:
          guard let newlineIndex = buffer.firstIndex(of: 0x0A) else {
            return emitted
          }

          let sizeLine = buffer[..<newlineIndex]
          buffer.removeSubrange(...newlineIndex)

          let trimmedBytes = trimTrailingCR(sizeLine)
          let hexString = String(decoding: trimmedBytes, as: UTF8.self)
          guard !hexString.isEmpty, hexString.allSatisfy({ $0.isHexDigit }) else {
            state = .finished
            return emitted
          }

          let declared = Int(hexString, radix: 16) ?? 0
          if declared == 0 {
            state = .expectingTrailer
            emitted.append(DecodedChunk(bytes: Data(), isTerminal: true))
          } else {
            state = .expectingData(remaining: declared)
          }
        case .expectingData(let remaining):
          guard buffer.count >= remaining + 2 else {
            return emitted
          }
          let payload = buffer.prefix(remaining)
          buffer.removeFirst(remaining)
          let hasCRLF =
            buffer.count >= 2
            && buffer[buffer.startIndex] == 0x0D
            && buffer[buffer.startIndex + 1] == 0x0A
          if hasCRLF {
            buffer.removeFirst(2)
            emitted.append(DecodedChunk(bytes: Data(payload), isTerminal: false))
          } else {
            emitted.append(DecodedChunk(bytes: Data(payload), isTerminal: false))
          }
          state = .expectingSize
        case .expectingTrailer:
          guard let newlineIndex = buffer.firstIndex(of: 0x0A) else {
            return emitted
          }
          let lineBytes = buffer[..<newlineIndex]
          buffer.removeSubrange(...newlineIndex)
          if trimTrailingCR(lineBytes).isEmpty {
            state = .finished
            return emitted
          }
        case .finished:
          return emitted
        }
      }
    }

    private func trimTrailingCR(_ data: Data) -> Data {
      if let last = data.last, last == 0x0D {
        return data.prefix(data.count - 1)
      }
      return data
    }
  }

  private static func appendHex(_ value: Int, into buffer: inout Data) {
    if value == 0 {
      buffer.append(0x30)
      return
    }
    var stack: [UInt8] = []
    var remaining = value
    while remaining > 0 {
      let nibble = remaining & 0xF
      stack.append(
        nibble < 10
          ? UInt8(0x30 + nibble)
          : UInt8(0x61 + (nibble - 10)))
      remaining >>= 4
    }
    buffer.append(contentsOf: stack.reversed())
  }
}
