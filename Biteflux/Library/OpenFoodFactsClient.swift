import BitefluxCore
import Foundation

/// Looks up barcodes on Open Food Facts. Reading needs no account; the API allows
/// 15 lookups a minute and asks every app to name itself in its User-Agent.
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
        var request = URLRequest(url: OpenFoodFacts.productURL(barcode: barcode))
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let answer: (Data, URLResponse)
        do {
            answer = try await session.data(for: request)
        } catch let error as URLError where Self.offlineCodes.contains(error.code) {
            throw Problem.offline
        }
        let (data, response) = answer

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200:
            do {
                return try OpenFoodFacts.lookup(barcode: barcode, from: data)
            } catch {
                throw Problem.unreadable
            }
        case 404:
            return .notFound
        case 429, 503:
            throw Problem.busy
        default:
            throw Problem.failed(status: status)
        }
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
