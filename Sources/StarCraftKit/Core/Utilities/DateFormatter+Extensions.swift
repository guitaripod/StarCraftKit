import Foundation

extension ISO8601DateFormatter {
    /// Full ISO8601 date-time formatter (no fractional seconds), e.g. `2026-06-28T18:00:00Z`.
    ///
    /// `nonisolated(unsafe)` is sound here: ISO8601DateFormatter is configured once and
    /// its formatting/parsing methods are thread-safe.
    nonisolated(unsafe) static let pandaScore: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// ISO8601 date-time formatter that accepts fractional seconds, e.g. `2026-06-28T18:00:00.123Z`.
    nonisolated(unsafe) static let pandaScoreFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

extension DateFormatter {
    /// Simple `yyyy-MM-dd` formatter for date-only values such as player birthdays.
    static let yearMonthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

extension JSONDecoder.DateDecodingStrategy {
    /// Date decoding that tolerates PandaScore's mix of ISO8601 timestamps
    /// (with or without fractional seconds) and `yyyy-MM-dd` date-only strings.
    ///
    /// Optional `Date` properties are safe against explicit JSON `null` because the
    /// synthesized `Decodable` calls `decodeIfPresent`, which short-circuits on null
    /// before this strategy runs.
    static let pandaScore = custom { decoder in
        let container = try decoder.singleValueContainer()
        let dateString = try container.decode(String.self)

        if let date = ISO8601DateFormatter.pandaScore.date(from: dateString) {
            return date
        }
        if let date = ISO8601DateFormatter.pandaScoreFractional.date(from: dateString) {
            return date
        }
        if let date = DateFormatter.yearMonthDay.date(from: dateString) {
            return date
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Expected ISO8601 (optionally fractional) or yyyy-MM-dd date, got \"\(dateString)\"."
        )
    }
}

extension JSONEncoder.DateEncodingStrategy {
    /// Symmetric encoding strategy that emits ISO8601 strings the `.pandaScore`
    /// decoder can read back, keeping any re-encoded model round-trippable.
    static let pandaScore = custom { date, encoder in
        var container = encoder.singleValueContainer()
        try container.encode(ISO8601DateFormatter.pandaScore.string(from: date))
    }
}
