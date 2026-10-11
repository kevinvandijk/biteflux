import XCTest
@testable import BitefluxCore

/// Reads real label photos through OpenRouter, the same way the app does. Skipped unless
/// `OPENROUTER_KEY` holds a key and `LABEL_PHOTOS` points at a folder of JPEG photos, each at most
/// 1568 pixels on its long side (`sips -Z 1568` makes them so). It prints what was read from each
/// photo for a check against the label. Every photo costs a little on the key's OpenRouter account.
final class LabelReaderLiveTests: XCTestCase {
    func testReadsLabelPhotos() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let key = environment["OPENROUTER_KEY"], !key.isEmpty, let folder = environment["LABEL_PHOTOS"] else {
            throw XCTSkip("Set OPENROUTER_KEY and LABEL_PHOTOS to read real label photos.")
        }
        let photos = try FileManager.default.contentsOfDirectory(atPath: folder)
            .filter { ["jpg", "jpeg"].contains(($0 as NSString).pathExtension.lowercased()) }
            .sorted()
        XCTAssertFalse(photos.isEmpty, "There are no JPEG photos in \(folder).")

        for photo in photos {
            var request = URLRequest(url: LabelReader.endpoint)
            request.httpMethod = "POST"
            request.timeoutInterval = 90
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            for (name, value) in LabelReader.headers {
                request.setValue(value, forHTTPHeaderField: name)
            }
            let jpeg = try Data(contentsOf: URL(fileURLWithPath: folder).appendingPathComponent(photo))
            request.httpBody = LabelReader.requestBody(jpeg: jpeg)

            let started = Date()
            let (data, response) = try await URLSession.shared.data(for: request)
            let seconds = Date().timeIntervalSince(started)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else {
                XCTFail("\(photo): HTTP \(status): \(String(decoding: data.prefix(500), as: UTF8.self))")
                continue
            }
            let usage = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["usage"] ?? "none"
            do {
                let reading = try LabelReader.reading(fromAnswer: data)
                print("\(photo) in \(String(format: "%.1f", seconds)) s: \(reading)\n  usage: \(usage)")
            } catch {
                XCTFail("\(photo) in \(String(format: "%.1f", seconds)) s: \(error)\n  answer: \(String(decoding: data.prefix(2000), as: UTF8.self))")
            }
        }
    }
}
