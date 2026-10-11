import BitefluxCore
import Foundation

/// Looks up barcodes and searches names on Open Food Facts. Reading needs no account; the API
/// allows 15 lookups and 10 searches a minute and asks every app to name itself in its User-Agent.
struct OpenFoodFactsClient {
    enum Problem: LocalizedError {
        case offline
        case busy
        case unreadable
        case failed(status: Int)

        var errorDescription: String? {
            switch self {
            case .offline:
                "There's no internet connection, so Open Food Facts can't be reached."
            case .busy:
                "Open Food Facts is busy. Try again in a minute."
            case .unreadable:
                "Open Food Facts sent an answer Biteflux can't read. Try again later."
            case let .failed(status):
                "Open Food Facts didn't answer properly (error \(status)). Try again later."
            }
        }
    }

    var session: URLSession = .shared

    func lookup(barcode: String) async throws -> OpenFoodFacts.Lookup {
        let (data, status) = try await get(OpenFoodFacts.productURL(barcode: barcode), timeout: 15)
        switch status {
        case 200:
            do {
                return try OpenFoodFacts.lookup(barcode: barcode, from: data)
            } catch {
                throw Problem.unreadable
            }
        case 404:
            return .notFound
        default:
            throw Self.problem(status: status)
        }
    }

    func search(_ terms: String) async throws -> [OpenFoodFacts.Product] {
        let (data, status) = try await get(OpenFoodFacts.searchURL(for: terms), timeout: 20)
        guard status == 200 else { throw Self.problem(status: status) }
        do {
            return try OpenFoodFacts.products(fromSearch: data)
        } catch {
            throw Problem.unreadable
        }
    }

    private func get(_ url: URL, timeout: TimeInterval) async throws -> (Data, Int) {
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = timeout
        do {
            let (data, response) = try await session.data(for: request)
            return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
        } catch let error as URLError where Self.offlineCodes.contains(error.code) {
            throw Problem.offline
        }
    }

    private static func problem(status: Int) -> Problem {
        status == 429 || status == 503 ? .busy : .failed(status: status)
    }

    private static let offlineCodes: [URLError.Code] = [
        .notConnectedToInternet, .networkConnectionLost, .timedOut,
        .cannotFindHost, .cannotConnectToHost, .dataNotAllowed,
    ]

    private static let userAgent: String = {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        return "Biteflux/\(version) (https://github.com/kevinvandijk/biteflux)"
    }()
}
