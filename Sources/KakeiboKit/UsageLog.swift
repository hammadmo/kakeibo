import Foundation

/// One assistant reply's token use, read from a Claude Code log line.
public struct UsageRecord: Equatable, Sendable {
    public var time: Date
    /// The folder Claude Code worked in (the log's `cwd`).
    public var project: String
    public var session: String
    public var model: String
    public var input: Int
    public var output: Int
    public var cacheWrite5m: Int
    public var cacheWrite1h: Int
    public var cacheRead: Int
    /// Message id + request id. A reply logged twice counts once.
    public var key: String

    public var tokens: Int { input + output + cacheWrite5m + cacheWrite1h + cacheRead }

    /// Estimated USD at API prices; 0 for an unknown model.
    public var cost: Double {
        guard let p = Pricing.price(for: model) else { return 0 }
        let perToken = 1.0 / 1_000_000
        return (Double(input) * p.input + Double(output) * p.output
            + Double(cacheWrite5m) * p.cacheWrite5m + Double(cacheWrite1h) * p.cacheWrite1h
            + Double(cacheRead) * p.cacheRead) * perToken
    }

    public var unknownModel: Bool { Pricing.price(for: model) == nil }
}

/// Parses Claude Code's `~/.claude/projects/**/*.jsonl` lines.
///
/// Lines can be megabytes (tool results), so this never decodes a whole line:
/// it finds `"usage":{` with memmem, decodes only that small object, and reads
/// the few string fields it needs straight from the bytes. Inside a JSON string
/// a quote is always escaped, so `"key":` with a bare quote is a real key.
public enum UsageLog {
    /// nil for anything but an assistant reply with usage. `fallbackProject`
    /// is used when a line has no `cwd`.
    public static func parse(line: Data, fallbackProject: String = "") -> UsageRecord? {
        line.withUnsafeBytes { parse(bytes: $0, fallbackProject: fallbackProject) }
    }

    public static func parse(bytes: UnsafeRawBufferPointer, fallbackProject: String = "") -> UsageRecord? {
        guard let usageAt = Bytes.first(#""usage":{"#, in: bytes),
              // The top-level type is the line's last "type" key.
              Bytes.string(after: #""type":""#, in: bytes, fromEnd: true) == "assistant",
              let model = Bytes.string(after: #""model":""#, in: bytes, fromEnd: false),
              model != "<synthetic>",
              let stamp = Bytes.string(after: #""timestamp":""#, in: bytes, fromEnd: true),
              let time = Timestamp.parse(stamp)
        else { return nil }

        let start = usageAt + 8 // the "{"
        guard let end = Bytes.closingBrace(from: start, in: bytes) else { return nil }
        let usage = UnsafeRawBufferPointer(rebasing: bytes[start...end])
        func int(_ key: StaticString) -> Int { Bytes.int(after: key, in: usage) ?? 0 }

        let write = int(#""cache_creation_input_tokens":"#)
        let write1h = int(#""ephemeral_1h_input_tokens":"#)
        let write5m = Bytes.int(after: #""ephemeral_5m_input_tokens":"#, in: usage) ?? (write - write1h)
        let id = Bytes.string(after: #""id":""#, in: bytes, fromEnd: false) ?? UUID().uuidString
        let request = Bytes.string(after: #""requestId":""#, in: bytes, fromEnd: true) ?? ""
        return UsageRecord(
            time: time,
            project: Bytes.string(after: #""cwd":""#, in: bytes, fromEnd: true) ?? fallbackProject,
            session: Bytes.string(after: #""sessionId":""#, in: bytes, fromEnd: true) ?? "",
            model: model,
            input: int(#""input_tokens":"#),
            output: int(#""output_tokens":"#),
            cacheWrite5m: max(write5m, 0),
            cacheWrite1h: write1h,
            cacheRead: int(#""cache_read_input_tokens":"#),
            key: "\(id)|\(request)"
        )
    }
}

/// "2026-11-22T13:37:03.692Z" without a DateFormatter (they are slow).
enum Timestamp {
    static func parse(_ text: String) -> Date? {
        let u = Array(text.utf8)
        guard u.count >= 20, u[4] == 45, u[7] == 45, u[10] == 84, u[13] == 58, u[16] == 58 else { return nil }
        func num(_ from: Int, _ count: Int) -> Int32? {
            var v: Int32 = 0
            for i in from..<from + count {
                let d = Int32(u[i]) - 48
                guard d >= 0 && d <= 9 else { return nil }
                v = v * 10 + d
            }
            return v
        }
        guard let y = num(0, 4), let mo = num(5, 2), let d = num(8, 2),
              let h = num(11, 2), let mi = num(14, 2), let s = num(17, 2) else { return nil }
        var t = tm()
        t.tm_year = y - 1900; t.tm_mon = mo - 1; t.tm_mday = d
        t.tm_hour = h; t.tm_min = mi; t.tm_sec = s
        var fraction = 0.0
        if u.count > 20, u[19] == 46 {
            var scale = 0.1
            var i = 20
            while i < u.count, u[i] >= 48, u[i] <= 57 { fraction += Double(u[i] - 48) * scale; scale /= 10; i += 1 }
        }
        return Date(timeIntervalSince1970: Double(timegm(&t)) + fraction)
    }
}

/// Byte search helpers for UsageLog.
enum Bytes {
    static func first(_ needle: StaticString, in hay: UnsafeRawBufferPointer) -> Int? {
        guard let base = hay.baseAddress, hay.count >= needle.utf8CodeUnitCount,
              let hit = memmem(base, hay.count, needle.utf8Start, needle.utf8CodeUnitCount) else { return nil }
        return base.distance(to: UnsafeRawPointer(hit))
    }

    static func last(_ needle: StaticString, in hay: UnsafeRawBufferPointer) -> Int? {
        let n = needle.utf8CodeUnitCount
        guard hay.count >= n else { return nil }
        let pattern = UnsafeBufferPointer(start: needle.utf8Start, count: n)
        var i = hay.count - n
        while i >= 0 {
            if hay[i] == pattern[0] {
                var j = 1
                while j < n && hay[i + j] == pattern[j] { j += 1 }
                if j == n { return i }
            }
            i -= 1
        }
        return nil
    }

    /// The integer after `key` (which ends with the colon), or nil.
    static func int(after key: StaticString, in hay: UnsafeRawBufferPointer) -> Int? {
        guard let at = first(key, in: hay) else { return nil }
        var i = at + key.utf8CodeUnitCount
        while i < hay.count, hay[i] == 0x20 { i += 1 }
        var value = 0
        var digits = 0
        while i < hay.count, hay[i] >= 48, hay[i] <= 57 { value = value * 10 + Int(hay[i] - 48); i += 1; digits += 1 }
        return digits > 0 ? value : nil
    }

    /// The JSON string value after `key` (which ends with the opening quote).
    static func string(after key: StaticString, in hay: UnsafeRawBufferPointer, fromEnd: Bool) -> String? {
        guard let at = fromEnd ? last(key, in: hay) : first(key, in: hay) else { return nil }
        var i = at + key.utf8CodeUnitCount
        var out: [UInt8] = []
        while i < hay.count {
            let c = hay[i]
            if c == UInt8(ascii: "\"") { return String(decoding: out, as: UTF8.self) }
            if c == UInt8(ascii: "\\"), i + 1 < hay.count {
                i += 1
                let e = hay[i]
                switch e {
                case UInt8(ascii: "n"): out.append(0x0A)
                case UInt8(ascii: "t"): out.append(0x09)
                case UInt8(ascii: "u"): return nil // rare in ids, paths, and stamps; skip the line's field
                default: out.append(e)
                }
            } else {
                out.append(c)
            }
            i += 1
        }
        return nil
    }

    /// Index of the `}` that closes the object opening at `start`, skipping strings.
    static func closingBrace(from start: Int, in hay: UnsafeRawBufferPointer) -> Int? {
        var depth = 0
        var inString = false
        var i = start
        while i < hay.count {
            let c = hay[i]
            if inString {
                if c == UInt8(ascii: "\\") { i += 1 } else if c == UInt8(ascii: "\"") { inString = false }
            } else if c == UInt8(ascii: "\"") {
                inString = true
            } else if c == UInt8(ascii: "{") {
                depth += 1
            } else if c == UInt8(ascii: "}") {
                depth -= 1
                if depth == 0 { return i }
            }
            i += 1
        }
        return nil
    }
}
