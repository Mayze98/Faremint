import SwiftUI
import PhotosUI

struct PhotoPickerSection: View {
    @Binding var imageData: Data?
    @State private var selectedItem: PhotosPickerItem?

    /// Maximum photo size in bytes (5 MB). Images larger than this are
    /// re-compressed to JPEG at reduced quality to keep SwiftData and
    /// Firebase Storage usage reasonable.
    private static let maxPhotoBytes = 5 * 1024 * 1024

    var body: some View {
        Section("Photo") {
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Button(role: .destructive) {
                    self.imageData = nil
                    selectedItem = nil
                } label: {
                    Label("Remove Photo", systemImage: "trash")
                }
            }

            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label(imageData == nil ? "Add Photo" : "Change Photo", systemImage: "camera")
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    imageData = Self.compressIfNeeded(data)
                }
            }
        }
    }

    /// If the raw photo data exceeds the size limit, re-encodes it as JPEG
    /// with progressively lower quality until it fits.
    private static func compressIfNeeded(_ data: Data) -> Data {
        guard data.count > maxPhotoBytes, let image = UIImage(data: data) else { return data }
        for quality in stride(from: 0.7, through: 0.1, by: -0.1) {
            if let compressed = image.jpegData(compressionQuality: quality),
               compressed.count <= maxPhotoBytes {
                return compressed
            }
        }
        // Last resort: lowest quality
        return image.jpegData(compressionQuality: 0.1) ?? data
    }
}
