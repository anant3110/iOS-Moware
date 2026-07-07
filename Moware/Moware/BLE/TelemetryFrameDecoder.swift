import Foundation

enum TelemetryDecodeError: Error {
    case invalidLength(expected: Int, actual: Int)
    case unexpectedMode(UInt8)
}

/// Decodes a Nexus response notification: a 1-byte `core_mode_t` tag
/// identifying the payload kind, followed by the payload itself. For
/// `STREAM_MODE`, the payload is the firmware's `source_time_stream_frame_t`:
///
/// ```c
/// typedef struct {
///     uint8_t timestamp[4];      // uint32 big-endian (byte[0] = (timestamp >> 24) & 0xFF)
///     uint8_t offset[15];
///     uint8_t source[15];
///     uint8_t data[13 * 15];     // 15 frames x 13-byte bit-packed sample
/// } source_time_stream_frame_t;
/// ```
enum TelemetryFrameDecoder {
    private static let streamPayloadByteCount = 229
    static let expectedByteCount = 1 + streamPayloadByteCount
    private static let frameCount = 15
    private static let bytesPerFrame = 13

    static func decode(_ data: Data) throws -> SourceTimeStreamFrame {
        guard data.count == expectedByteCount else {
            throw TelemetryDecodeError.invalidLength(expected: expectedByteCount, actual: data.count)
        }
        let modeByte = data.first!
        guard modeByte == CoreModeOpcode.stream.rawValue else {
            throw TelemetryDecodeError.unexpectedMode(modeByte)
        }
        let bytes = [UInt8](data.dropFirst())

        let timestamp = (UInt32(bytes[0]) << 24)
            | (UInt32(bytes[1]) << 16)
            | (UInt32(bytes[2]) << 8)
            | UInt32(bytes[3])

        let offsets = Array(bytes[4..<19])
        let sources = Array(bytes[19..<34])

        var samples: [RawIMUSample] = []
        samples.reserveCapacity(frameCount)

        for i in 0..<frameCount {
            let start = 34 + i * bytesPerFrame
            let frame = bytes[start..<start + bytesPerFrame]
            var reader = BitReader(frame.prefix(10))

            let rawQx = reader.readBits(11)
            let rawQy = reader.readBits(11)
            let rawQz = reader.readBits(11)
            let rawQw = reader.readBits(11)
            let rawAx = reader.readBits(11)
            let rawAy = reader.readBits(11)
            let rawAz = reader.readBits(11)

            let gravityBytes = Array(frame.suffix(3))

            samples.append(RawIMUSample(
                frameIndex: i,
                timeOffset: offsets[i],
                sourceIndex: sources[i],
                quatI: Double(rawQx) / 1000.0 - 1.0,
                quatJ: Double(rawQy) / 1000.0 - 1.0,
                quatK: Double(rawQz) / 1000.0 - 1.0,
                quatReal: Double(rawQw) / 1000.0 - 1.0,
                accelX: Double(rawAx) / 10.0 - 80.0,
                accelY: Double(rawAy) / 10.0 - 80.0,
                accelZ: Double(rawAz) / 10.0 - 80.0,
                gravityX: (Double(gravityBytes[0]) / 100.0 - 1.0) * 10.0,
                gravityY: (Double(gravityBytes[1]) / 100.0 - 1.0) * 10.0,
                gravityZ: (Double(gravityBytes[2]) / 100.0 - 1.0) * 10.0
            ))
        }

        return SourceTimeStreamFrame(baseTimestamp: timestamp, samples: samples)
    }
}
