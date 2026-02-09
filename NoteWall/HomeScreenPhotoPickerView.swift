import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit
import Photos

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
    @State private var isLockIconActive = false
    @State private var hasActivatedLockThisSession = false
    @State private var isPhotoLibraryPickerPresented = false
    @State private var photoLibrarySelection: PhotosPickerItem?
    @State private var showPermissionAlert = false
    @State private var showPresetsSheet = false

    private enum PickerType: Identifiable {
        case camera
        case files

        var id: String {
            switch self {
            case .camera: return "camera"
            case .files: return "files"
            }
        }
    }

    private var selectedPreset: PresetOption? {
        guard let option = backgroundMode.presetOption else { return nil }
        switch option {
        case .black: return .black
        case .gray: return .gray
        case .none: return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { showSourceOptions = true }) {
                HStack(spacing: 12) {
                    Image(systemName: backgroundMode == .photo && (!backgroundPhotoData.isEmpty || backgroundPhotoAvailable) ? "photo.fill" : "photo")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isLockIconActive ? .appAccent : .gray)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add Lock Screen Photo")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)

                        Text(isSavingBackground ? "Saving…" : "Choose your own photo")
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
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: backgroundMode)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: isLockIconActive)
        .confirmationDialog(
            "",
            isPresented: $showSourceOptions,
            titleVisibility: .hidden
        ) {
            Button(role: .none) {
                checkPhotoLibraryPermission {
                    isPhotoLibraryPickerPresented = true
                }
                showSourceOptions = false
            } label: {
                Label("Photo Library", systemImage: "photo.on.rectangle")
                    .labelStyle(LeadingMenuLabelStyle())
            }


            
            Button(role: .none) {
                showSourceOptions = false
                showPresetsSheet = true
            } label: {
                Label("Presets", systemImage: "paintpalette")
                    .labelStyle(LeadingMenuLabelStyle())
            }

            Button("Cancel", role: .cancel) { }
        }
        .photosPicker(
            isPresented: $isPhotoLibraryPickerPresented,
            selection: $photoLibrarySelection,
            matching: .images
        )
        .onChange(of: photoLibrarySelection) { _, newValue in
            guard let item = newValue else { return }
            Task {
                do {
                    if let data = try await item.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            processPickedData(data)
                        }
                    } else {
                        await MainActor.run {
                            reportFailure("Unable to load selected photo.")
                        }
                    }
                } catch {
                    await MainActor.run {
                        reportFailure("Unable to load selected photo.")
                    }
                }

                await MainActor.run {
                    photoLibrarySelection = nil
                    isPhotoLibraryPickerPresented = false
                }
            }
        }
        .onChange(of: backgroundMode) { _, _ in
            syncLockIconState()
        }
        .onChange(of: backgroundPhotoData) { _, _ in
            syncLockIconState()
        }
        .sheet(item: $activePicker) { picker in
            switch picker {
            case .camera:
                CameraPickerView { image in
                    guard let data = image.jpegData(compressionQuality: 0.95) ?? image.pngData() else {
                        reportFailure("Unable to process captured photo.")
                        return
                    }
                    processPickedData(data)
                } onCancel: {
                    activePicker = nil
                } onDismiss: {
                    activePicker = nil
                }

            case .files:
                DocumentPickerView { data in
                    processPickedData(data)
                } onError: { message in
                    reportFailure(message)
                } onCancel: {
                    activePicker = nil
                } onDismiss: {
                    activePicker = nil
                }
            }
        }
        .onAppear {
            syncLockIconState()
        }
        .alert(isPresented: $showPermissionAlert) {
            Alert(
                title: Text("Access Required"),
                message: Text("Please allow access to your photo library to select a wallpaper."),
                primaryButton: .default(Text("Settings"), action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }),
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showPresetsSheet) {
            PresetSelectorSheet(
                title: "Lock Screen Preset",
                selectedPreset: selectedPreset,
                onSelect: { preset in
                    selectPreset(preset)
                    showPresetsSheet = false
                },
                onCancel: {
                    showPresetsSheet = false
                }
            )
        }
    }

    private func reportFailure(_ message: String) {
        statusMessage = message
        statusColor = .red
        isSavingBackground = false
        isLockIconActive = false
        hasActivatedLockThisSession = false
    }

    private func processPickedData(_ data: Data) {
        print("📸 LockScreenBackgroundPickerView: Processing picked photo data")
        print("   Data size: \(data.count) bytes")
        isSavingBackground = true
        statusMessage = "Saving background…"
        statusColor = .secondary

        Task {
            do {
                guard let image = UIImage(data: data) else {
                    throw HomeScreenImageManagerError.unableToEncodeImage
                }
                print("   Image size: \(image.size)")
                
                guard let prepared = Self.preparedBackgroundImage(from: image) else {
                    throw HomeScreenImageManagerError.unableToEncodeImage
                }
                print("   Prepared image size: \(prepared.image.size)")
                
                // Save to file system for wallpaper generation
                try HomeScreenImageManager.saveLockScreenBackgroundSource(prepared.image)
                print("✅ Saved lock screen background to TextEditor folder")
                
                if let url = HomeScreenImageManager.lockScreenBackgroundSourceURL() {
                    print("   File path: \(url.path)")
                    print("   File exists: \(FileManager.default.fileExists(atPath: url.path))")
                }
                
                await MainActor.run {
                    // Set photo data and mode
                    backgroundPhotoData = prepared.data
                    backgroundMode = .photo
                    backgroundOption = .black // Set a default option when using photo
                    
                    // Update UI state
                    isSavingBackground = false
                    statusMessage = nil
                    statusColor = .gray
                    
                    // Activate the icon to show cyan color
                    isLockIconActive = true
                    hasActivatedLockThisSession = true
                    
                    print("✅ LockScreenBackgroundPickerView: Photo data processed successfully")
                    print("   Mode set to: .photo")
                    print("   Photo data bytes: \(backgroundPhotoData.count)")
                    print("   Icon activated: true")
                }
            } catch {
                print("❌ LockScreenBackgroundPickerView: Failed to save photo: \(error)")
                await MainActor.run {
                    reportFailure("Unable to save selected photo: \(error.localizedDescription)")
                    isSavingBackground = false
                }
            }
        }
    }

    private func selectPreset(_ preset: PresetOption) {
        print("🎨 LockScreenBackgroundPickerView: Selecting preset \(preset.title)")
        
        // Light impact haptic for preset selection
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        isSavingBackground = false
        statusMessage = nil
        statusColor = .gray
        
        // Clear photo data and file system storage
        print("   Clearing photo data and removing background file...")
        backgroundPhotoData = Data()
        HomeScreenImageManager.removeLockScreenBackgroundSource()
        
        // Set the preset mode and option
        backgroundOption = preset.lockScreenOption
        backgroundMode = LockScreenBackgroundMode.preset(for: preset.lockScreenOption)
        
        print("   ✅ Preset selected")
        print("      Background option: \(backgroundOption)")
        print("      Background mode: \(backgroundMode)")
        print("   ℹ️  User must click 'Update Wallpaper Now' to apply")
        
        // Update icon state
        isLockIconActive = false
        hasActivatedLockThisSession = false
        
        // Don't trigger automatic update - let user click "Update Wallpaper Now" button
        // This matches the Home Screen preset behavior
    }

    private func syncLockIconState() {
        let shouldActivate = backgroundMode == .photo && !backgroundPhotoData.isEmpty
        print("🔄 LockScreenBackgroundPickerView: syncLockIconState -> mode=\(backgroundMode), photoDataEmpty=\(backgroundPhotoData.isEmpty)")
        if shouldActivate {
            isLockIconActive = true
            hasActivatedLockThisSession = true
        } else {
            isLockIconActive = false
            hasActivatedLockThisSession = false
        }
        print("   Icon active: \(isLockIconActive)")
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
        case .left: return 8
        @unknown default: return 1
        }
    }

    private func checkPhotoLibraryPermission(completion: @escaping () -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            completion()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    DispatchQueue.main.async {
                        completion()
                    }
                }
            }
        case .denied, .restricted:
            showPermissionAlert = true
        @unknown default:
            showPermissionAlert = true
        }
    }
}

// MARK: - Camera Picker

@available(iOS 16.0, *)
private struct CameraPickerView: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    let onCancel: () -> Void
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, onCancel: onCancel, onDismiss: onDismiss)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.modalPresentationStyle = .fullScreen
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onImagePicked: (UIImage) -> Void
        private let onCancel: () -> Void
        private let onDismiss: () -> Void

        init(onImagePicked: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void, onDismiss: @escaping () -> Void) {
            self.onImagePicked = onImagePicked
            self.onCancel = onCancel
            self.onDismiss = onDismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            } else {
                onCancel()
            }
            picker.dismiss(animated: true) {
                self.onDismiss()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
            picker.dismiss(animated: true) {
                self.onDismiss()
            }
        }
    }
}

// MARK: - Photo Library Picker

// MARK: - Document Picker

@available(iOS 16.0, *)
private struct DocumentPickerView: UIViewControllerRepresentable {
    let onPick: (Data) -> Void
    let onError: (String) -> Void
    let onCancel: () -> Void
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onError: onError, onCancel: onCancel, onDismiss: onDismiss)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: [.image], asCopy: true)
        controller.delegate = context.coordinator
        controller.allowsMultipleSelection = false
        
        // Try to set initial directory to "On My iPhone" if possible
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            controller.directoryURL = documentsURL
        }
        
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) { }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onPick: (Data) -> Void
        private let onError: (String) -> Void
        private let onCancel: () -> Void
        private let onDismiss: () -> Void

        init(onPick: @escaping (Data) -> Void, onError: @escaping (String) -> Void, onCancel: @escaping () -> Void, onDismiss: @escaping () -> Void) {
            self.onPick = onPick
            self.onError = onError
            self.onCancel = onCancel
            self.onDismiss = onDismiss
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                DispatchQueue.main.async {
                    self.onError("No file selected.")
                    self.onCancel()
                    self.onDismiss()
                }
                return
            }

            do {
                let data = try Data(contentsOf: url)
                DispatchQueue.main.async {
                    self.onPick(data)
                    self.onDismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    self.onError("Unable to read selected file.")
                    self.onDismiss()
                }
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            DispatchQueue.main.async {
                self.onCancel()
                self.onDismiss()
            }
        }
    }
}

// MARK: - Branded Preset Selector Sheet

@available(iOS 16.0, *)
struct PresetSelectorSheet: View {
    let title: String
    let selectedPreset: PresetOption?
    let onSelect: (PresetOption) -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private let accentColor = Color.appAccent
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(UIColor.systemBackground), Color(UIColor.secondarySystemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [accentColor, accentColor.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("Choose a Preset")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("Select a solid color background")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Preset cards
                    HStack(spacing: 20) {
                        ForEach(PresetOption.allCases) { preset in
                            PresetCard(
                                preset: preset,
                                isSelected: selectedPreset == preset,
                                accentColor: accentColor,
                                onTap: {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    onSelect(preset)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

@available(iOS 16.0, *)
private struct PresetCard: View {
    let preset: PresetOption
    let isSelected: Bool
    let accentColor: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Color preview circle
                ZStack {
                    Circle()
                        .fill(preset.previewColor)
                        .frame(width: 80, height: 80)
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    
                    if isSelected {
                        Circle()
                            .strokeBorder(accentColor, lineWidth: 4)
                            .frame(width: 88, height: 88)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(accentColor)
                            .background(Circle().fill(Color.white).padding(4))
                            .offset(x: 28, y: 28)
                    }
                }
                
                // Label
                Text(preset.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(isSelected ? accentColor : .primary)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(UIColor.tertiarySystemBackground))
                    .shadow(color: isSelected ? accentColor.opacity(0.3) : Color.black.opacity(0.08), radius: isSelected ? 12 : 6, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isSelected ? accentColor : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}
