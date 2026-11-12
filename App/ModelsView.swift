import SwiftUI
import UniformTypeIdentifiers

struct ModelsView: View {
    @EnvironmentObject private var models: ModelManager
    @EnvironmentObject private var settings: AppSettings
    @State private var customURL = ""
    @State private var importing = false
    @State private var pendingDelete: String?

    var body: some View {
        NavigationStack {
            List {
                if let error = models.lastError {
                    Section { Text(error).foregroundStyle(.red).font(.footnote) }
                }

                Section {
                    NavigationLink { CalibrationView() } label: {
                        Label("Calibrate: compare models on your voice", systemImage: "slider.horizontal.3")
                    }
                }

                Section("Installed") {
                    if models.installed.isEmpty {
                        Text("No models yet. Download one below or import a ggml .bin file.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    ForEach(models.installed, id: \.self) { file in
                        HStack {
                            Button {
                                settings.selectedModelFile = file
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(displayName(file)).font(.subheadline)
                                        Text(sizeText(file)).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if settings.selectedModelFile == file {
                                        Image(systemName: "checkmark").foregroundStyle(.tint)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Button(role: .destructive) { pendingDelete = file } label: {
                                Image(systemName: "trash").foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Delete \(displayName(file))")
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { models.installed[$0] }.forEach(models.delete)
                    }
                }

                Section("Download from Hugging Face") {
                    ForEach(WhisperModelInfo.catalog) { model in
                        catalogRow(model)
                    }
                }

                Section {
                    TextField("https://…/ggml-model.bin", text: $customURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Download from URL") {
                        if let url = URL(string: customURL.trimmingCharacters(in: .whitespaces)) {
                            models.download(from: url)
                            customURL = ""
                        }
                    }
                    .disabled(URL(string: customURL)?.scheme?.hasPrefix("http") != true)
                    Button("Import from Files…") { importing = true }
                } header: {
                    Text("Custom model")
                } footer: {
                    Text("Any whisper.cpp ggml model works. Models are stored on this device only.")
                }
            }
            .navigationTitle("Models")
            .confirmationDialog(
                "Delete \(pendingDelete.map(displayName) ?? "model")?",
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let file = pendingDelete { models.delete(file) }
                    pendingDelete = nil
                }
            } message: {
                Text("Frees \(pendingDelete.map(sizeText) ?? "space"). You can download it again any time.")
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.data]) { result in
                if case .success(let url) = result { models.importModel(from: url) }
            }
        }
    }

    private func displayName(_ file: String) -> String {
        WhisperModelInfo.catalog.first { $0.file == file }?.title ?? file
    }

    private func sizeText(_ file: String) -> String {
        let bytes = (try? FileManager.default.attributesOfItem(atPath: models.url(for: file).path)[.size] as? Int64) ?? 0
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    @ViewBuilder
    private func catalogRow(_ model: WhisperModelInfo) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.title).font(.subheadline.weight(.medium))
                Text("\(model.detail) · \(ByteCountFormatter.string(fromByteCount: model.bytes, countStyle: .file))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let progress = models.progress[model.file] {
                ProgressView(value: progress).frame(width: 60)
                Button { models.cancelDownload(model.file) } label: { Image(systemName: "xmark.circle") }
                    .buttonStyle(.borderless)
            } else if models.installed.contains(model.file) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Button { models.download(model) } label: { Image(systemName: "arrow.down.circle") }
                    .buttonStyle(.borderless)
            }
        }
    }
}
