import Foundation

/// Reads unsigned integer fields from a byte buffer, MSB-first, at arbitrary
/// bit widths. Used to unpack the Nexus firmware's bit-packed IMU samples,
/// which interleave several sub-byte-width fields across byte boundaries.
struct BitReader {
    private let bytes: [UInt8]
    private var bitOffset: Int = 0

    init(_ bytes: some Sequence<UInt8>) {
        self.bytes = Array(bytes)
    }

    /// Reads `count` (1...32) bits starting at the current cursor, advances
    /// the cursor, and returns the unsigned value.
    mutating func readBits(_ count: Int) -> UInt32 {
        let value = Self.readBits(bytes, bitOffset: bitOffset, count: count)
        bitOffset += count
        return value
    }

    private static func readBits(_ bytes: [UInt8], bitOffset: Int, count: Int) -> UInt32 {
        precondition(count >= 1 && count <= 32)
        var result: UInt32 = 0
        var remaining = count
        var pos = bitOffset
        while remaining > 0 {
            let byteIndex = pos / 8
            let bitInByte = pos % 8
            let bitsLeftInByte = 8 - bitInByte
            let take = min(bitsLeftInByte, remaining)
            let shift = bitsLeftInByte - take
            let mask = UInt8((1 << take) - 1)
            let chunk = (bytes[byteIndex] >> shift) & mask
            result = (result << take) | UInt32(chunk)
            pos += take
            remaining -= take
        }
        return result
    }
}
