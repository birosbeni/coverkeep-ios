import Foundation
import SwiftUI
import WarrantyRules

extension WarrantyRulesEngine {
    /// The app-wide engine over the bundled, owner-vetted rule sets. The
    /// bundled JSON is validated at load; a failure means a corrupt build,
    /// so failing fast beats showing wrong legal information.
    static let shared: WarrantyRulesEngine = {
        do {
            return try WarrantyRulesEngine.bundled()
        } catch {
            fatalError("Bundled warranty rule sets failed to load: \(error)")
        }
    }()
}

extension EnvironmentValues {
    @Entry var warrantyEngine: WarrantyRulesEngine = .shared
}
