import Foundation
import Testing

@testable import GaiaCore

struct HTTPChunkedTransferTests {
  @Test
  func encodeChunkProducesCorrectHexHeaderAndCRLF() {
    let payload = Data("event: status\n\n".utf8)
    let encoded = HTTPChunkedTransfer.encodeChunk(payload)
    let expectedHex = String(payload.count, radix: 16)
    let prefix = encoded.prefix(expectedHex.utf8.count + 2)
    let prefixString = String(decoding: prefix, as: UTF8.self)
    #expect(prefixString == "\(expectedHex)\r\n")
    let suffix = encoded.suffix(2)
    #expect(Array(suffix) == [0x0D, 0x0A])
    #expect(encoded.count == expectedHex.utf8.count + 2 + payload.count + 2)
  }

  @Test
  func terminatorIsCanonicalZeroChunk() {
    let terminator = HTTPChunkedTransfer.terminator()
    let expected = Data("0\r\n\r\n".utf8)
    #expect(terminator == expected)
  }

  @Test
  func decoderParsesSingleChunk() {
    let decoder = HTTPChunkedTransfer.Decoder()
    let payload = Data("event: hello\n\n".utf8)
    var wire = Data("\(String(payload.count, radix: 16))\r\n".utf8)
    wire.append(payload)
    wire.append(Data("\r\n".utf8))

    let chunks = decoder.consume(wire)
    #expect(chunks.count == 1)
    #expect(chunks.first?.bytes == payload)
    #expect(chunks.first?.isTerminal == false)
  }

  @Test
  func decoderParsesMultipleChunksAcrossBoundaries() {
    let decoder = HTTPChunkedTransfer.Decoder()
    let first = Data("a".utf8)
    let second = Data("bb".utf8)
    var wire = Data("\(String(first.count, radix: 16))\r\n".utf8)
    wire.append(first)
    wire.append(Data("\r\n".utf8))
    wire.append(Data("\(String(second.count, radix: 16))\r\n".utf8))
    wire.append(second)
    wire.append(Data("\r\n".utf8))

    // Feed byte by byte to exercise the boundary handling at every offset.
    var collected: [HTTPChunkedTransfer.DecodedChunk] = []
    for byte in wire {
      collected.append(contentsOf: decoder.consume(Data([byte])))
    }

    #expect(collected.count == 2)
    #expect(collected[0].bytes == first)
    #expect(collected[1].bytes == second)
  }

  @Test
  func decoderReportsTerminalChunkExactlyOnce() {
    let decoder = HTTPChunkedTransfer.Decoder()
    let wire = Data("0\r\n\r\n".utf8)
    let chunks = decoder.consume(wire)
    #expect(chunks.count == 1)
    #expect(chunks.first?.isTerminal == true)
    #expect(chunks.first?.bytes.isEmpty == true)
  }

  @Test
  func decoderIgnoresTrailingBytesAfterFinish() {
    let decoder = HTTPChunkedTransfer.Decoder()
    _ = decoder.consume(Data("0\r\n\r\n".utf8))
    let trailing = decoder.consume(Data("garbage".utf8))
    #expect(trailing.isEmpty)
  }
}
