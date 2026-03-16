import SwiftUI
import PhotosUI

struct PhotoPickerSection: View {
    @Binding var imageData: Data?
    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        Section("Receipt Photo") {
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
                    imageData = data
                }
            }
        }
    }
}
