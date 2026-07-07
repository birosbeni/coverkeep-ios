import Foundation

/// Country choices for the purchase form. EU/EEA members (their consumer
/// law is what the rules engine models); the user's own region is included
/// even when it's outside the list so the picker never fights the locale.
enum CountryOptions {

    static let euAndEEA: [String] = [
        "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR",
        "DE", "GR", "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL",
        "PL", "PT", "RO", "SK", "SI", "ES", "SE",
        "IS", "LI", "NO",
    ]

    /// Picker codes, localized-name sorted, with the locale's region
    /// appended when it isn't already present.
    static func pickerCodes(for locale: Locale = .current) -> [String] {
        var codes = euAndEEA
        if let region = locale.region?.identifier, !codes.contains(region) {
            codes.append(region)
        }
        return codes.sorted { name($0, in: locale) < name($1, in: locale) }
    }

    static func name(_ code: String, in locale: Locale = .current) -> String {
        locale.localizedString(forRegionCode: code) ?? code
    }

    /// The default country for a new item: the user's region, or HU (the
    /// home market) when the locale carries none.
    static func defaultCode(for locale: Locale = .current) -> String {
        locale.region?.identifier ?? "HU"
    }
}
