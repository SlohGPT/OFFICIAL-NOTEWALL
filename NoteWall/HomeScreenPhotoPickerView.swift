import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

@available(iOS 16.0, *)
struct HomeScreenPhotoPickerView: View {
    @Binding var isSavingHomeScreenPhoto: Bool
    @Binding var homeScreenStatusMessage: String?
    @Binding var homeScreenStatusColor: Color
    @Binding var homeScreenImageAvailable: Bool

    let handlePickedHomeScreenData: (Data) -> Void

    @State private var showSourceOptions = false
    @State private var activePicker: PickerType?

    private enum PickerType: Identifiable {
        case camera
        case photoLibrary
        case files

        var id: String {
            switch self {
            case .camera: return "camera"
            case .photoLibrary: return "photoLibrary"
            case .files: return "files"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: { showSourceOptions = true }) {
                HStack(spacing: 12) {
                    Image(systemName: homeScreenImageAvailable ? "photo.fill" : "photo")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(homeScreenImageAvailable ? .appAccent : .secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(homeScreenImageAvailable ? "Home Screen Photo" : "Add Home Screen Photo")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)

                        Text(isSavingHomeScreenPhoto ? "Saving…" : "Choose a photo to keep your Home Screen consistent.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }
            .buttonStyle(.plain)
            .disabled(isSavingHomeScreenPhoto)
            .contentShape(Rectangle())

            if let message = homeScreenStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(homeScreenStatusColor)
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: homeScreenImageAvailable)
        .confirmationDialog(
            "",
            isPresented: $showSourceOptions,
            titleVisibility: .hidden
        ) {
            Button(role: .none) {
                activePicker = .photoLibrary
            } label: {
                Label("Photo Library", systemImage: "photo.on.rectangle")
                    .labelStyle(LeadingMenuLabelStyle())
            }

            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button(role: .none) {
                    activePicker = .camera
                } label: {
                    Label("Take Photo", systemImage: "camera")
                        .labelStyle(LeadingMenuLabelStyle())
                }
            }

            Button(role: .none) {
                activePicker = .files
            } label: {
                Label("Choose File", systemImage: "folder")
                    .labelStyle(LeadingMenuLabelStyle())
            }

            Button("Cancel", role: .cancel) { }
        }
        .sheet(item: $activePicker) { picker in
            switch picker {
            case .camera:
                CameraPickerView { image in
                    guard let data = image.jpegData(compressionQuality: 0.95) ?? image.pngData() else {
                        reportLoadFailure("Unable to process captured photo.")
                        activePicker = nil
                        return
                    }
                    processPickedData(data)
                    activePicker = nil
                } onCancel: {
                    activePicker = nil
                }

            case .photoLibrary:
                PhotoLibraryPickerView { data in
                    processPickedData(data)
                    activePicker = nil
                } onError: { message in
                    reportLoadFailure(message)
                    activePicker = nil
                } onCancel: {
                    activePicker = nil
                }

            case .files:
                DocumentPickerView { data in
                    processPickedData(data)
                    activePicker = nil
                } onError: { message in
                    reportLoadFailure(message)
                    activePicker = nil
                } onCancel: {
                    activePicker = nil
                }
            }
        }
    }

    private func reportLoadFailure(_ message: String) {
        DispatchQueue.main.async {
            homeScreenStatusMessage = message
            homeScreenStatusColor = .red
            isSavingHomeScreenPhoto = false
        }
    }

    private func processPickedData(_ data: Data) {
        DispatchQueue.main.async {
            handlePickedHomeScreenData(data)
        }
    }

}

@available(iOS 16.0, *)
struct HomeScreenQuickPresetsView: View {
    @AppStorage("homeScreenPresetSelection") private var homeScreenPresetSelectionRaw = PresetOption.black.rawValue

    @Binding var isSavingHomeScreenPhoto: Bool
    @Binding var homeScreenStatusMessage: String?
    @Binding var homeScreenStatusColor: Color

    let handlePickedHomeScreenData: (Data) -> Void

    private var selectedPreset: PresetOption? {
        PresetOption(rawValue: homeScreenPresetSelectionRaw)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PresetOptionsRow(
                title: "Quick presets",
                isDisabled: isSavingHomeScreenPhoto,
                selectedPreset: selectedPreset,
                selectionAction: applyPreset
            )
        }
    }

    private func applyPreset(_ preset: PresetOption) {
        guard preset != selectedPreset else { return }

        isSavingHomeScreenPhoto = true
        homeScreenStatusMessage = "Applying \(preset.title.lowercased()) preset…"
        homeScreenStatusColor = .secondary

        applyPresetLocally(preset)
    }

    private func reportLoadFailure(_ message: String) {
        homeScreenStatusMessage = message
        homeScreenStatusColor = .red
        isSavingHomeScreenPhoto = false
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            homeScreenPresetSelectionRaw = selectedPreset?.rawValue ?? homeScreenPresetSelectionRaw
        }
    }

    private func applyPresetLocally(_ preset: PresetOption) {
        let image = solidColorImage(color: preset.lockScreenOption.uiColor)

        do {
            try HomeScreenImageManager.saveHomeScreenImage(image)
            switch preset {
            case .black:
                try? HomeScreenImageManager.saveHomePresetBlack(image)
            case .gray:
                try? HomeScreenImageManager.saveHomePresetGray(image)
            }

            homeScreenPresetSelectionRaw = preset.rawValue
            homeScreenStatusMessage = "\(preset.title) preset saved."
            homeScreenStatusColor = .green
            isSavingHomeScreenPhoto = false
        } catch {
            reportLoadFailure("Failed to save \(preset.title.lowercased()) preset.")
        }
    }

    private func solidColorImage(color: UIColor) -> UIImage {
        let size = CGSize(width: 1290, height: 2796)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

@available(iOS 16.0, *)
private struct LeadingMenuLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.icon
            configuration.title
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@available(iOS 16.0, *)
private struct PresetOptionsRow: View {
    let title: String
    let isDisabled: Bool
    let selectedPreset: PresetOption?
    let selectionAction: (PresetOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                ForEach(PresetOption.allCases) { preset in
                    Button {
                        selectionAction(preset)
                    } label: {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(preset.previewColor)
                            .frame(height: 50)
                            .overlay(
                                Text(preset.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(preset.textColor)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(selectedPreset == preset ? Color.appAccent : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isDisabled)
                    .opacity(isDisabled ? 0.6 : 1.0)
                }
            }
        }
        .padding(.top, 8)
    }
}

@available(iOS 16.0, *)
struct LockScreenBackgroundPickerView: View {
    @Binding var isSavingBackground: Bool
    @Binding var statusMessage: String?
    @Binding var statusColor: Color
    @Binding var backgroundMode: LockScreenBackgroundMode
    @Binding var backgroundOption: LockScreenBackgroundOption
    @Binding var backgroundPhotoData: Data

    var backgroundPhotoAvailable: Bool

    @State private var showSourceOptions = false
    @State private var activePicker: PickerType?

    private enum PickerType: Identifiable {
        case camera
        case photoLibrary
        case files

        var id: String {
            switch self {
            case .camera: return "camera"
            case .photoLibrary: return "photoLibrary"
            case .files: return "files"
            }
        }
    }

    private var selectedPreset: PresetOption? {
        guard let option = backgroundMode.presetOption else { return nil }
        switch option {
        case .black: return .black
        case .gray: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: { showSourceOptions = true }) {
                HStack(spacing: 12) {
                    Image(systemName: backgroundMode == .photo && backgroundPhotoAvailable ? "photo.fill" : "photo")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(backgroundMode == .photo && backgroundPhotoAvailable ? .appAccent : .secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Lock Screen Background")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)

                        Text(isSavingBackground ? "Saving…" : "Choose a photo to sit behind your notes on the lock screen.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }
            .buttonStyle(.plain)
            .disabled(isSavingBackground)
            .contentShape(Rectangle())

            if let message = statusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }

            PresetOptionsRow(
                title: "Presets",
                isDisabled: isSavingBackground,
                selectedPreset: selectedPreset,
                selectionAction: selectPreset
            )
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: backgroundMode)
        .confirmationDialog(
            "",
            isPresented: $showSourceOptions,
            titleVisibility: .hidden
        ) {
            Button(role: .none) {
                activePicker = .photoLibrary
            } label: {
                Label("Photo Library", systemImage: "photo.on.rectangle")
                    .labelStyle(LeadingMenuLabelStyle())
            }

            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button(role: .none) {
                    activePicker = .camera
                } label: {
                    Label("Take Photo", systemImage: "camera")
                        .labelStyle(LeadingMenuLabelStyle())
                }
            }

            Button(role: .none) {
                activePicker = .files
            } label: {
                Label("Choose File", systemImage: "folder")
                    .labelStyle(LeadingMenuLabelStyle())
            }

            Button("Cancel", role: .cancel) { }
        }
        .sheet(item: $activePicker) { picker in
            switch picker {
            case .camera:
                CameraPickerView { image in
                    guard let data = image.jpegData(compressionQuality: 0.95) ?? image.pngData() else {
                        reportFailure("Unable to process captured photo.")
                        activePicker = nil
                        return
                    }
                    processPickedData(data)
                    activePicker = nil
                } onCancel: {
                    activePicker = nil
                }

            case .photoLibrary:
                PhotoLibraryPickerView { data in
                    processPickedData(data)
                    activePicker = nil
                } onError: { message in
                    reportFailure(message)
                    activePicker = nil
                } onCancel: {
                    activePicker = nil
                }

            case .files:
                DocumentPickerView { data in
                    processPickedData(data)
                    activePicker = nil
                } onError: { message in
                    reportFailure(message)
                    activePicker = nil
                } onCancel: {
                    activePicker = nil
                }
            }
        }
    }

    private func reportFailure(_ message: String) {
        statusMessage = message
        statusColor = .red
        isSavingBackground = false
    }

    private func processPickedData(_ data: Data) {
        isSavingBackground = true
        statusMessage = "Saving background…"
        statusColor = .secondary

        Task {
            if let image = UIImage(data: data),
               let prepared = Self.preparedBackgroundImage(from: image) {
                try? HomeScreenImageManager.saveLockScreenBackgroundSource(prepared.image)
                await MainActor.run {
                    backgroundPhotoData = prepared.data
                    backgroundMode = .photo
                    isSavingBackground = false
                    statusMessage = "Background photo saved!"
                    statusColor = .green
                }
            } else {
                await MainActor.run {
                    reportFailure("Unable to use selected photo.")
                }
            }
        }
    }

    private func selectPreset(_ preset: PresetOption) {
        isSavingBackground = false
        backgroundPhotoData = Data()
        backgroundOption = preset.lockScreenOption
        backgroundMode = LockScreenBackgroundMode.preset(for: preset.lockScreenOption)
        statusMessage = "\(preset.title) preset selected."
        statusColor = .green
        HomeScreenImageManager.removeLockScreenBackgroundSource()
    }

    private static func preparedBackgroundImage(from image: UIImage) -> (image: UIImage, data: Data)? {
        let sizeLimit = 2_500_000 // Keep comfortably under the 4 MB AppStorage ceiling
        let minDimension: CGFloat = 1200
        var targetMaxDimension: CGFloat = min(2048, max(image.size.width, image.size.height))

        var bestData: Data?
        var bestImage: UIImage?

        for _ in 0..<6 {
            let scale = min(1, targetMaxDimension / max(image.size.width, image.size.height))
            let targetSize = CGSize(
                width: max(1, image.size.width * scale),
                height: max(1, image.size.height * scale)
            )

            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            format.opaque = true // JPEG has no alpha channel; marking opaque saves bytes

            let normalizedImage = renderNormalizedImage(image, targetSize: targetSize, format: format)

            var quality: CGFloat = 0.8
            while quality >= 0.35 {
                if let data = normalizedImage.jpegData(compressionQuality: quality) {
                    if data.count <= sizeLimit {
                        return (normalizedImage, data)
                    }

                    if bestData == nil || data.count < (bestData?.count ?? .max) {
                        bestData = data
                        bestImage = normalizedImage
                    }
                }
                quality -= 0.1
            }

            if targetMaxDimension <= minDimension {
                // We're already quite small; give back the lowest-quality attempt we have.
                if let data = normalizedImage.jpegData(compressionQuality: 0.35) {
                    return (normalizedImage, data)
                }
                break
            }

            targetMaxDimension *= 0.75
        }

    guard let data = bestData, let bestImage else {
            guard let fallbackData = image.jpegData(compressionQuality: 0.4) else { return nil }
            return (image, fallbackData)
        }

        return (bestImage, data)
    }

    private static func renderNormalizedImage(_ image: UIImage, targetSize: CGSize, format: UIGraphicsImageRendererFormat) -> UIImage {
        if image.imageOrientation == .up {
            let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        }

        guard let cgImage = image.cgImage else {
            let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        }

        let exifOrientation = exifOrientation(for: image.imageOrientation)
        let ciImage = CIImage(cgImage: cgImage).oriented(forExifOrientation: exifOrientation)
        guard let outputCGImage = sharedCIContext.createCGImage(ciImage, from: ciImage.extent) else {
            let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        }

        let orientedImage = UIImage(cgImage: outputCGImage, scale: image.scale, orientation: .up)
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            orientedImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    private static let sharedCIContext = CIContext(options: [.useSoftwareRenderer: false])

    private static func exifOrientation(for orientation: UIImage.Orientation) -> Int32 {
        switch orientation {
        case .up: return 1
        case .down: return 3
        case .left: return 8
        case .right: return 6
        case .upMirrored: return 2
        case .downMirrored: return 4
        case .leftMirrored: return 5
        case .rightMirrored: return 7
        @unknown default: return 1
        }
    }
}

// MARK: - Camera Picker

@available(iOS 16.0, *)
private struct CameraPickerView: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onImagePicked: (UIImage) -> Void
        private let onCancel: () -> Void

        init(onImagePicked: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImagePicked = onImagePicked
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            } else {
                onCancel()
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Photo Library Picker

@available(iOS 16.0, *)
private struct PhotoLibraryPickerView: UIViewControllerRepresentable {
    let onPick: (Data) -> Void
    let onError: (String) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onError: onError, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) { }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onPick: (Data) -> Void
        private let onError: (String) -> Void
        private let onCancel: () -> Void

        init(onPick: @escaping (Data) -> Void, onError: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onError = onError
            self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider else {
                onCancel()
                picker.dismiss(animated: true)
                return
            }

            let typeIdentifier = UTType.image.identifier

            provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                DispatchQueue.main.async {
                    if let data, !data.isEmpty {
                        self.onPick(data)
                    } else {
                        self.onError("Unable to load selected photo.")
                    }
                }
            }

            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Document Picker

@available(iOS 16.0, *)
private struct DocumentPickerView: UIViewControllerRepresentable {
    let onPick: (Data) -> Void
    let onError: (String) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onError: onError, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: [.image], asCopy: true)
        controller.delegate = context.coordinator
        controller.allowsMultipleSelection = false
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) { }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onPick: (Data) -> Void
        private let onError: (String) -> Void
        private let onCancel: () -> Void

        init(onPick: @escaping (Data) -> Void, onError: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onError = onError
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                DispatchQueue.main.async {
                    self.onError("No file selected.")
                    self.onCancel()
                }
                return
            }

            do {
                let data = try Data(contentsOf: url)
                DispatchQueue.main.async {
                    self.onPick(data)
                }
            } catch {
                DispatchQueue.main.async {
                    self.onError("Unable to read selected file.")
                }
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            DispatchQueue.main.async {
                self.onCancel()
            }
        }
    }
}
