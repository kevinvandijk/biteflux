import BitefluxCore
import UIKit

/// Sends a label photo to GPT Luna 6 through OpenRouter with your own OpenRouter key and returns
/// what it read. Each photo costs a fraction of a cent on your OpenRouter account.
struct LabelReaderClient {
    enum Problem: LocalizedError {
        case noKey
        case keyRejected
        case keyLimited
        case outOfCredits
        case offline
        case busy
        case failed(status: Int)
        case unusablePhoto
        case reading(LabelReader.Problem)

        var errorDescription: String? {
            switch self {
            case .noKey:
                "Add your OpenRouter key to read labels."
            case .keyRejected:
                "OpenRouter didn't accept your key. Check it, or add a new one."
            case .keyLimited:
                "OpenRouter didn't let this key read the label, for example because it reached its spending limit. Check the key at openrouter.ai."
            case .outOfCredits:
                "Your OpenRouter account is out of credits. Add credits at openrouter.ai, or copy the label by hand."
            case .offline:
                "There's no internet connection, so the label can't be read. Copy it by hand instead."
            case .busy:
                "OpenRouter is busy right now. Try again in a minute."
            case let .failed(status):
                "Reading the label didn't work (error \(status)). Try again, or copy it by hand."
            case .unusablePhoto:
                "That photo can't be used. Take another one."
            case .reading(.notALabel):
                "That photo doesn't show a nutrition table. Take one of the table on the pack."
            case .reading(.onlyPerPortion):
                "The label only gives values per portion and doesn't say what a portion weighs. Copy it by hand."
            case .reading(.declined):
                "This photo was declined. Copy the label by hand instead."
            case .reading(.interrupted):
                "Reading the label stopped partway. Try again, or copy it by hand."
            case .reading(.cutOff), .reading(.unreadableAnswer):
                "The answer couldn't be read. Try again, or copy the label by hand."
            }
        }
    }

    var session: URLSession = .shared

    func read(_ photo: UIImage) async throws -> LabelReader.Reading {
        guard let key = APIKeyStore.key else { throw Problem.noKey }
        guard let jpeg = photo.labelJPEG() else { throw Problem.unusablePhoto }

        var request = URLRequest(url: LabelReader.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        for (name, value) in LabelReader.headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        request.httpBody = LabelReader.requestBody(jpeg: jpeg)

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
                return try LabelReader.reading(fromAnswer: data)
            } catch let problem as LabelReader.Problem {
                throw Problem.reading(problem)
            }
        case 401:
            throw Problem.keyRejected
        case 402:
            throw Problem.outOfCredits
        case 403:
            // OpenRouter answers 403 both for a flagged photo and for a key past its limit.
            throw LabelReader.wasFlagged(errorAnswer: data) ? Problem.reading(.declined) : Problem.keyLimited
        case 408, 429, 500, 502, 503, 504, 529:
            throw Problem.busy
        default:
            throw Problem.failed(status: status)
        }
    }

    private static let offlineCodes: [URLError.Code] = [
        .notConnectedToInternet, .networkConnectionLost, .timedOut,
        .cannotFindHost, .cannotConnectToHost, .dataNotAllowed,
    ]
}

private extension UIImage {
    /// The photo as JPEG, scaled so its long side is at most 1568 pixels, which keeps a label
    /// readable. Smaller photos upload faster and cost less.
    func labelJPEG() -> Data? {
        let longSide = max(size.width, size.height) * scale
        guard longSide > 0 else { return nil }
        let factor = min(1, 1568 / longSide)
        let target = CGSize(width: size.width * scale * factor, height: size.height * scale * factor)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let scaled = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
        return scaled.jpegData(compressionQuality: 0.8)
    }
}
