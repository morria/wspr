import Foundation

/// Encodes a standard WSPR "Type 1" message (callsign + 4-character grid + power)
/// into the 162 channel symbols (values 0–3) that drive the 4-FSK modulator.
///
/// This is a Swift port of the well-tested C encoder in the Etherkit **JTEncode**
/// library (`wspr_encode`), itself derived from Joe Taylor K1JT's WSJT / WSPR sources
/// and Andy Talbot G4JNT's documented coding process:
///
///   1. Pack callsign (28 bits), grid (15 bits) and power (7 bits) into 50 data bits.
///   2. Convolutionally encode (constraint length K = 32, rate 1/2) → 162 bits.
///   3. Interleave using a bit-reversal permutation.
///   4. Merge with the 162-bit pseudo-random sync vector to form 4-level symbols.
///
/// Compound / portable callsigns (containing `/`) use WSPR's Type 2/3 hashed encoding,
/// which is intentionally not implemented here; `encode(...)` throws for those so the
/// app never transmits a subtly malformed frame.
enum WSPRMessage {

    static let symbolCount = 162

    enum EncodingError: Error, LocalizedError {
        case emptyCallsign
        case unsupportedCompoundCallsign
        case invalidGrid

        var errorDescription: String? {
            switch self {
            case .emptyCallsign:
                return "Enter your callsign before transmitting."
            case .unsupportedCompoundCallsign:
                return "Compound callsigns (with “/”) aren't supported for transmit yet."
            case .invalidGrid:
                return "Enter a valid 4- or 6-character grid locator."
            }
        }
    }

    /// Encode a message into 162 symbols. `power` is snapped to the nearest legal WSPR level.
    static func encode(callsign: String, grid: String, powerDBm: Int) throws -> [UInt8] {
        let rawCall = callsign.trimmingCharacters(in: .whitespaces).uppercased()
        guard !rawCall.isEmpty else { throw EncodingError.emptyCallsign }
        guard !rawCall.contains("/") else { throw EncodingError.unsupportedCompoundCallsign }

        let grid4 = String(grid.trimmingCharacters(in: .whitespaces).uppercased().prefix(4))
        guard grid4.count == 4, MaidenheadLocator.isValid(grid4) else { throw EncodingError.invalidGrid }

        let power = WSPRPower.nearestValid(powerDBm)

        let dataBytes = packType1(callsign: rawCall, grid: grid4, power: power)
        let convolved = convolve(dataBytes)
        let interleaved = interleave(convolved)
        return mergeSyncVector(interleaved)
    }

    // MARK: - Character coding

    /// WSPR character value: digits 0–9, letters A–Z → 10–35, space → 36.
    private static func code(_ ch: Character) -> Int {
        if let a = ch.asciiValue {
            if a >= 48 && a <= 57 { return Int(a) - 48 }        // 0-9
            if a >= 65 && a <= 90 { return Int(a) - 55 }        // A-Z
        }
        return 36                                                // space / other
    }

    // MARK: - Bit packing (Type 1)

    private static func packType1(callsign: String, grid: String, power: Int) -> [UInt8] {
        // Normalise callsign to a 6-character, space-padded array with the digit in slot 2.
        var call = Array(callsign.prefix(6))
        while call.count < 6 { call.append(" ") }

        // pad_callsign: if the digit is in slot 1 with a letter in slot 2, shift right one.
        if call[1].isNumber && call[2].isLetter {
            call = [" ", call[0], call[1], call[2], call[3], call[4]]
        }

        var n = code(call[0])
        n = n * 36 + code(call[1])
        n = n * 10 + code(call[2])
        n = n * 27 + (code(call[3]) - 10)
        n = n * 27 + (code(call[4]) - 10)
        n = n * 27 + (code(call[5]) - 10)

        let g = Array(grid.unicodeScalars).map { Int($0.value) }
        let A = Int(UnicodeScalar("A").value)
        let zero = Int(UnicodeScalar("0").value)
        var m = ((179 - 10 * (g[0] - A) - (g[2] - zero)) * 180) + (10 * (g[1] - A)) + (g[3] - zero)
        m = (m * 128) + power + 64

        // Pack 28-bit `n` and 22-bit `m` into an 11-byte buffer (MSB first), rest zero.
        var c = [UInt8](repeating: 0, count: 11)
        let un = UInt32(bitPattern: Int32(n))
        let um = UInt32(bitPattern: Int32(m))

        c[3] = UInt8((un & 0x0f) << 4)
        var nn = un >> 4
        c[2] = UInt8(nn & 0xff); nn >>= 8
        c[1] = UInt8(nn & 0xff); nn >>= 8
        c[0] = UInt8(nn & 0xff)

        c[6] = UInt8((um & 0x03) << 6)
        var mm = um >> 2
        c[5] = UInt8(mm & 0xff); mm >>= 8
        c[4] = UInt8(mm & 0xff); mm >>= 8
        c[3] |= UInt8(mm & 0x0f)

        return c
    }

    // MARK: - Convolutional encoding (K = 32, rate 1/2)

    private static let poly0: UInt32 = 0xf2d0_5351
    private static let poly1: UInt32 = 0xe461_3c47

    private static func parity(_ value: UInt32) -> UInt8 {
        UInt8(value.nonzeroBitCount & 1)
    }

    private static func convolve(_ c: [UInt8]) -> [UInt8] {
        var s = [UInt8](repeating: 0, count: symbolCount)
        var reg: UInt32 = 0
        var bitCount = 0

        outer: for byte in c {
            for j in 0..<8 {
                let inputBit: UInt32 = ((UInt32(byte) << j) & 0x80) == 0x80 ? 1 : 0
                reg = (reg << 1) | inputBit

                s[bitCount] = parity(reg & poly0); bitCount += 1
                s[bitCount] = parity(reg & poly1); bitCount += 1
                if bitCount >= symbolCount { break outer }
            }
        }
        return s
    }

    // MARK: - Interleaving (bit-reversal permutation)

    private static func interleave(_ s: [UInt8]) -> [UInt8] {
        var d = [UInt8](repeating: 0, count: symbolCount)
        var i = 0
        for j in 0..<256 {
            // Reverse the 8-bit index.
            var rev = 0
            var tmp = j
            for k in 0..<8 {
                if tmp & 0x01 != 0 { rev |= (1 << (7 - k)) }
                tmp >>= 1
            }
            if rev < symbolCount {
                d[rev] = s[i]
                i += 1
            }
            if i >= symbolCount { break }
        }
        return d
    }

    // MARK: - Sync vector

    /// The 162-bit WSPR synchronisation vector.
    static let syncVector: [UInt8] = [
        1,1,0,0,0,0,0,0,1,0,0,0,1,1,1,0,0,0,1,0,0,
        1,0,1,1,1,1,0,0,0,0,0,0,0,1,0,0,1,0,1,0,0,
        0,0,0,0,1,0,1,1,0,0,1,1,0,1,0,0,0,1,1,0,1,
        0,0,0,0,1,1,0,1,0,1,0,1,0,1,0,0,1,0,0,1,0,
        1,1,0,0,0,1,1,0,1,0,1,0,0,0,1,0,0,0,0,0,1,
        0,0,1,0,0,1,1,1,0,1,1,0,0,1,1,0,1,0,0,0,1,
        1,1,0,0,0,0,0,1,0,1,0,0,1,1,0,0,0,0,0,0,0,
        1,1,0,1,0,1,1,0,0,0,1,1,0,0,0
    ]

    private static func mergeSyncVector(_ g: [UInt8]) -> [UInt8] {
        var symbols = [UInt8](repeating: 0, count: symbolCount)
        for i in 0..<symbolCount {
            symbols[i] = syncVector[i] + 2 * g[i]
        }
        return symbols
    }
}
