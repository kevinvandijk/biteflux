import AVFoundation
import BitefluxCore
import PhotosUI
import SwiftUI
import Vision
import VisionKit

/// The B4 Scan screen: the camera reads a barcode, the name on the front of a pack, or a photo
/// of the nutrition label, and hands what it found to the library.
struct ScanView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case label = "Label"
        case barcode = "Barcode"
        case name = "Name"

        var id: Self { self }

        var hint: String {
            switch self {
            case .label: "Fit the nutrition table in view, then take the photo."
            case .barcode: "Point the camera at the barcode."
            case .name: "Tap the product's name on the pack."
            }
        }
    }

    /// How much is left of today's goal, shown at the top as on the design.
    var remainingKcal: Double
    /// What was found, or nil when you'd rather type or search.
    var onFinish: (AddFoodSheet.Start?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var camera = Camera.checking
    @State private var mode = Mode.barcode
    @State private var scanner = ScannerHandle()
    @State private var finished = false
    @State private var reading = false
    @State private var problem: String?
    @State private var askingForKey = false
    @State private var waitingPhoto: UIImage?
    @State private var photoItem: PhotosPickerItem?

    private let labelReader = LabelReaderClient()

    private enum Camera {
        case checking
        case ready
        case denied
        case unavailable
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch camera {
            case .checking:
                ProgressView().tint(Ember.text)
            case .ready:
                LiveScanner(mode: mode, handle: scanner, onBarcode: found(barcode:), onText: found(name:))
                    .id(mode)
                    .ignoresSafeArea()
            case .denied, .unavailable:
                noCamera
            }
            VStack(spacing: 0) {
                topBar
                Spacer()
                if camera == .ready {
                    controls
                }
            }
            .padding(.horizontal, 20)
            if reading {
                readingCard
            }
        }
        .foregroundStyle(Ember.text)
        .task {
            camera = await Self.checkCamera()
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            photoItem = nil
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let photo = UIImage(data: data) {
                    read(photo)
                } else {
                    problem = "That photo couldn't be opened. Try another one."
                }
            }
        }
        .sheet(isPresented: $askingForKey) {
            APIKeyForm {
                if let photo = waitingPhoto {
                    waitingPhoto = nil
                    read(photo)
                }
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button("Close") { dismiss() }
                .font(Ember.sans(16, weight: .medium))
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(.black.opacity(0.5), in: Capsule())
            Spacer()
            Text(verbatim: "\(remainingKcal.wholeNumber) kcal left")
                .font(Ember.sans(14, relativeTo: .subheadline))
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(.black.opacity(0.5), in: Capsule())
        }
        .padding(.top, 8)
    }

    private var controls: some View {
        VStack(spacing: 14) {
            Text(verbatim: problem ?? mode.hint)
                .font(Ember.sans(15))
                .foregroundStyle(problem == nil ? Ember.text : Ember.failed)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            if mode == .label {
                HStack(spacing: 28) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title2)
                            .frame(width: 52, height: 52)
                            .background(.black.opacity(0.5), in: Circle())
                    }
                    .accessibilityLabel("Choose a photo of a label")
                    Button(action: takeLabelPhoto) {
                        Circle()
                            .fill(Ember.text)
                            .frame(width: 72, height: 72)
                            .overlay(Circle().strokeBorder(Ember.background, lineWidth: 3).padding(4))
                    }
                    .accessibilityLabel("Take the photo")
                    // Keeps the shutter centred.
                    Color.clear.frame(width: 52, height: 52)
                }
                .disabled(reading)
            }
            Picker("Scan for", selection: $mode) {
                ForEach(Mode.allCases) { mode in
                    Text(verbatim: mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { problem = nil }
            typeInsteadButton
        }
        .padding(.bottom, 8)
    }

    private var typeInsteadButton: some View {
        Button {
            finish(nil)
        } label: {
            Text("Type a barcode or search instead")
                .font(Ember.sans(15, weight: .medium, relativeTo: .subheadline))
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Ember.accent)
    }

    /// The simulator, an old phone or a refused camera still lets you pick a label photo.
    private var noCamera: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(camera == .denied ? "Biteflux can't use the camera." : "There's no camera to scan with here.")
                .font(Ember.serif(26, relativeTo: .title))
            if camera == .denied {
                Text("Allow it in Settings, Privacy & Security, Camera, or pick a photo of a label instead.")
                    .font(Ember.sans(15))
                    .foregroundStyle(Ember.secondaryText)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .font(Ember.sans(15, weight: .bold))
                .foregroundStyle(Ember.accent)
            }
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Read a photo of a label", systemImage: "photo.on.rectangle")
                    .font(Ember.sans(16, weight: .bold, relativeTo: .headline))
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Ember.onAccent)
            .background(Ember.accent, in: Capsule())
            .disabled(reading)
            if let problem {
                Text(verbatim: problem)
                    .font(Ember.sans(14))
                    .foregroundStyle(Ember.failed)
                    .fixedSize(horizontal: false, vertical: true)
            }
            typeInsteadButton
        }
        .padding(20)
        .background(Ember.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 20)
    }

    private var readingCard: some View {
        VStack(spacing: 12) {
            ProgressView().tint(Ember.accent)
            Text("Reading the label…")
                .font(Ember.sans(15))
        }
        .padding(24)
        .background(Ember.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func found(barcode payload: String) {
        // A partly read code fails its check digit; the scanner keeps looking.
        guard let barcode = Barcode.normalized(payload) else { return }
        finish(.barcode(barcode))
    }

    private func found(name text: String) {
        let name = text.split(whereSeparator: \.isNewline).joined(separator: " ")
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        finish(.search(name))
    }

    private func takeLabelPhoto() {
        Task {
            guard let camera = scanner.scanner else { return }
            do {
                read(try await camera.capturePhoto())
            } catch {
                problem = "The camera couldn't take a photo. Try again."
            }
        }
    }

    private func read(_ photo: UIImage) {
        guard APIKeyStore.key != nil else {
            waitingPhoto = photo
            askingForKey = true
            return
        }
        reading = true
        problem = nil
        Task {
            defer { reading = false }
            do {
                let result = try await labelReader.read(photo)
                finish(.label(ProductDraft(reading: result)))
            } catch LabelReaderClient.Problem.keyRejected {
                problem = LabelReaderClient.Problem.keyRejected.localizedDescription
                waitingPhoto = photo
                askingForKey = true
            } catch {
                problem = error.localizedDescription
            }
        }
    }

    private func finish(_ start: AddFoodSheet.Start?) {
        // The scanner can report the same barcode more than once before the screen closes.
        guard !finished else { return }
        finished = true
        onFinish(start)
    }

    private static func checkCamera() async -> Camera {
        guard DataScannerViewController.isSupported else { return .unavailable }
        guard await AVCaptureDevice.requestAccess(for: .video) else { return .denied }
        return DataScannerViewController.isAvailable ? .ready : .denied
    }
}

/// Lets the Scan screen ask the live scanner for a photo.
private final class ScannerHandle {
    weak var scanner: DataScannerViewController?
}

/// Apple's live scanner, set up for one scan mode. Switching modes builds a new one.
private struct LiveScanner: UIViewControllerRepresentable {
    var mode: ScanView.Mode
    var handle: ScannerHandle
    var onBarcode: (String) -> Void
    var onText: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let types: Set<DataScannerViewController.RecognizedDataType> = switch mode {
        case .barcode: [.barcode(symbologies: [.ean13, .ean8, .upce])]
        case .label, .name: [.text()]
        }
        let scanner = DataScannerViewController(
            recognizedDataTypes: types,
            qualityLevel: mode == .barcode ? .balanced : .accurate,
            recognizesMultipleItems: mode == .name,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: mode != .label,
            isHighlightingEnabled: mode != .label
        )
        scanner.delegate = context.coordinator
        handle.scanner = scanner
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.parent = self
        if !scanner.isScanning {
            try? scanner.startScanning()
        }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var parent: LiveScanner

        init(parent: LiveScanner) {
            self.parent = parent
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard parent.mode == .barcode else { return }
            for case let .barcode(barcode) in addedItems {
                if let payload = barcode.payloadStringValue {
                    parent.onBarcode(payload)
                    return
                }
            }
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            guard parent.mode == .name, case let .text(text) = item else { return }
            parent.onText(text.transcript)
        }
    }
}

#Preview {
    ScanView(remainingKcal: 1626, onFinish: { _ in })
        .preferredColorScheme(.dark)
}
