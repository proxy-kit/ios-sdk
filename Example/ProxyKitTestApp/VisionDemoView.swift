//
//  VisionDemoView.swift
//  AIKitTestApp
//
//  Created by Pawan Dixit on 02/08/2025.
//

import SwiftUI
import SecureProxy
import PhotosUI

struct VisionDemoView: View {
    @Environment(ProxyKit.self) var visionProxy

    @State private var visionPrompt = ""
    @State private var selectedImage: UIImage? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var visionResponse: String? = nil
    @State private var isProcessing = false
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Vision (Image + Prompt)")
                .font(.title2.bold())

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label(selectedImage == nil ? "Select an image" : "Change image", systemImage: "photo")
            }
            .onChange(of: selectedPhotoItem) { oldValue, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        await MainActor.run {
                            selectedImage = image
                            visionResponse = nil
                            errorMessage = nil
                        }
                    }
                }
            }

            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .cornerRadius(12)
            }

            TextField("Ask a question about the image", text: $visionPrompt)
                .textFieldStyle(.roundedBorder)

            Button(action: runVisionDemo) {
                Label("Analyze Image", systemImage: "eye")
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedImage == nil || isProcessing || visionPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let visionResponse {
                Text("Result:")
                    .font(.headline)
                Text(visionResponse)
                    .padding(.bottom, 4)
                    .font(.body)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            }

            if let error = errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .bold()
            }

            if isProcessing {
                ProgressView()
                    .padding(.vertical)
            }
        }
        .padding(.vertical)
    }

    func runVisionDemo() {
        guard let image = selectedImage else { return }
        isProcessing = true
        errorMessage = nil
        visionResponse = nil
        Task {
            do {
                let result = try await visionProxy.chat(message: visionPrompt, images: [.image(image, compressionQuality: 0.5)])
                await MainActor.run {
                    visionResponse = result
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
            await MainActor.run { isProcessing = false }
        }
    }
}

#Preview {
    VisionDemoView()
}
