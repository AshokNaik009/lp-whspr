import SwiftUI
import UniformTypeIdentifiers

struct ModelsView: View {
    @EnvironmentObject private var models: ModelManager
    @EnvironmentObject private var settings: AppSettings
    @State private var customURL = ""
    @State private var importing = false

    var body: some View {
        NavigationStack {
            List {
                if let error = models.lastError {
                    Section { Text(error).foregroundStyle(.red).font(.footnote) }
                }

                Section("Installed") {
                    if models.installed.isEmpty {
                        Text("No models yet. Download one below or import a ggml .bin file.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    ForEach(models.installed, id: \.self) { file in
                        Button {
                            settings.selectedModelFile = file
                        } label: {
                            HStack {
                                Text(file).font(.subheadline)
                                Spacer()
                                if settings.selectedModelFile == file {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
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
            .fileImporter(isPresented: $importing, allowedContentTypes: [.data]) { result in
                if case .success(let url) = result { models.importModel(from: url) }
            }
        }
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
