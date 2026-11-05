import PhotosUI
import SwiftUI

/// Drives the scan flow: camera or photo → text recognition → review sheet.
@MainActor
@Observable
final class ReceiptScanner {
    var showingCamera = false
    var showingPhotoPicker = false
    var photoSelection: PhotosPickerItem?
    var isRecognizing = false
    var receiptToReview: ParsedReceipt?
    var errorMessage: String?

    var cameraAvailable: Bool { DocumentScannerView.isSupported }

    /// Opens the document camera when available (not on the simulator),
    /// otherwise falls back to the photo library.
    func start() {
        if cameraAvailable {
            showingCamera = true
        } else {
            showingPhotoPicker = true
        }
    }

    func process(_ images: [UIImage]) {
        showingCamera = false
        guard !images.isEmpty else { return }
        isRecognizing = true

        Task {
            defer { isRecognizing = false }
            do {
                let receipt = try await ReceiptTextRecognizer.parseReceipt(from: images)
                if receipt.isEmpty {
                    errorMessage = "Couldn't find any prices. Try scanning again, flat and well lit."
                } else {
                    receiptToReview = receipt
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func loadSelectedPhoto() {
        guard let item = photoSelection else { return }
        photoSelection = nil
        isRecognizing = true

        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                isRecognizing = false
                errorMessage = "That photo couldn't be loaded."
                return
            }
            process([image])
        }
    }
}

extension View {
    /// Attaches every sheet/cover the scan flow needs.
    func receiptScanning(_ scanner: ReceiptScanner, bill: Bill) -> some View {
        @Bindable var bindable = scanner
        return self
            .fullScreenCover(isPresented: $bindable.showingCamera) {
                DocumentScannerView(
                    onFinish: { scanner.process($0) },
                    onCancel: { scanner.showingCamera = false }
                )
                .ignoresSafeArea()
            }
            .photosPicker(
                isPresented: $bindable.showingPhotoPicker,
                selection: $bindable.photoSelection,
                matching: .images
            )
            .onChange(of: scanner.photoSelection) { _, newValue in
                if newValue != nil { scanner.loadSelectedPhoto() }
            }
            .sheet(item: $bindable.receiptToReview) { receipt in
                ScanReviewView(bill: bill, receipt: receipt)
            }
            .overlay {
                if scanner.isRecognizing {
                    ProgressView("Reading receipt…")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .alert(
                "Couldn't Read Receipt",
                isPresented: Binding(
                    get: { scanner.errorMessage != nil },
                    set: { if !$0 { scanner.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(scanner.errorMessage ?? "")
            }
    }
}
