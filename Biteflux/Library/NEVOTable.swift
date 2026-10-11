import BitefluxCore
import Foundation
import os

/// The NEVO table bundled with the app, read once on first use.
///
/// The CSV isn't in git: RIVM hands NEVO out to people who accept its conditions, and this
/// repository is public. Put your own download in `Biteflux/NEVO/` (see the README) and Xcode
/// bundles it. Without it the library works the same, just without NEVO search.
actor NEVOTable {
    static let shared = NEVOTable()

    private var cached: [NEVO.Food]?

    func foods() -> [NEVO.Food] {
        if let cached { return cached }
        let foods = Self.load()
        cached = foods
        return foods
    }

    private static func load() -> [NEVO.Food] {
        let log = Logger(subsystem: "Biteflux", category: "NEVO")
        guard let url = Bundle.main.url(forResource: NEVO.fileName, withExtension: "csv")
            ?? Bundle.main.url(forResource: NEVO.fileName, withExtension: "csv", subdirectory: "NEVO")
        else {
            log.info("\(NEVO.fileName, privacy: .public).csv isn't in the app, so NEVO search is off.")
            return []
        }
        do {
            return try NEVO.foods(fromCSV: String(contentsOf: url, encoding: .utf8))
        } catch {
            log.error("Couldn't read the NEVO table: \(String(describing: error), privacy: .public)")
            return []
        }
    }
}
