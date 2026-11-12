import Foundation

struct WhisperModelInfo: Identifiable, Hashable {
    let file: String
    let title: String
    let detail: String
    let bytes: Int64

    var id: String { file }
    var url: URL { URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(file)")! }

    static let catalog: [WhisperModelInfo] = [
        .init(file: "ggml-tiny.en-q5_1.bin", title: "Tiny (English)", detail: "Fastest, lowest accuracy", bytes: 32_166_155),
        .init(file: "ggml-base.en-q5_1.bin", title: "Base (English)", detail: "Fast, good for short dictation", bytes: 59_721_011),
        .init(file: "ggml-base-q5_1.bin", title: "Base (Multilingual)", detail: "Fast, 99 languages", bytes: 59_707_625),
        .init(file: "ggml-small.en-q5_1.bin", title: "Small (English)", detail: "Balanced, smaller download", bytes: 190_098_681),
        .init(file: "ggml-small-q5_1.bin", title: "Small (Multilingual)", detail: "Balanced, 99 languages", bytes: 190_085_487),
        .init(file: "ggml-large-v3-turbo-q5_0.bin", title: "Large v3 Turbo (Q5)", detail: "Recommended · best accuracy, 99 languages", bytes: 574_041_195),
        .init(file: "ggml-large-v3-turbo-q8_0.bin", title: "Large v3 Turbo (Q8)", detail: "Highest quality, 8 GB RAM devices", bytes: 874_188_075),
    ]

    static let recommendedFile = "ggml-large-v3-turbo-q5_0.bin"

    /// Most accurate installed model, preferring the recommended one, then later (larger) catalog entries.
    static func preferred(among installed: [String]) -> String? {
        if installed.contains(recommendedFile) { return recommendedFile }
        let ranked = catalog.map(\.file).reversed()
        return ranked.first(where: installed.contains) ?? installed.first
    }
}

@MainActor
final class ModelManager: NSObject, ObservableObject {
    static let shared = ModelManager()

    @Published private(set) var installed: [String] = []
    @Published private(set) var progress: [String: Double] = [:]
    @Published var lastError: String?

    private var tasks: [Int: String] = [:]
    private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Models", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var mutable = dir
            try? mutable.setResourceValues(values)
        }
        return dir
    }

    override init() {
        super.init()
        refresh()
    }

    func refresh() {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: Self.directory.path)) ?? []
        installed = files.filter { $0.hasSuffix(".bin") }.sorted()
        let settings = AppSettings.shared
        if let selected = settings.selectedModelFile, !installed.contains(selected) {
            settings.selectedModelFile = nil
        }
        if settings.selectedModelFile == nil { settings.selectedModelFile = WhisperModelInfo.preferred(among: installed) }
    }

    func url(for file: String) -> URL { Self.directory.appendingPathComponent(file) }

    var selectedModelURL: URL? {
        guard let file = AppSettings.shared.selectedModelFile, installed.contains(file) else { return nil }
        return url(for: file)
    }

    func download(_ model: WhisperModelInfo) {
        download(from: model.url, as: model.file)
    }

    func download(from url: URL, as fileName: String? = nil) {
        let name = fileName ?? url.lastPathComponent
        guard progress[name] == nil else { return }
        lastError = nil
        let task = session.downloadTask(with: url)
        tasks[task.taskIdentifier] = name
        progress[name] = 0
        task.resume()
    }

    func cancelDownload(_ file: String) {
        session.getAllTasks { tasks in
            Task { @MainActor in
                for task in tasks where self.tasks[task.taskIdentifier] == file { task.cancel() }
            }
        }
        progress[file] = nil
    }

    /// Copies a model the user picked from Files (e.g. a ggml .bin shared via AirDrop or iCloud Drive).
    func importModel(from source: URL) {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        let destination = url(for: source.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: source, to: destination)
            AppSettings.shared.selectedModelFile = destination.lastPathComponent
            refresh()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func delete(_ file: String) {
        try? FileManager.default.removeItem(at: url(for: file))
        Task { await WhisperEngine.shared.unload() }
        refresh()
    }
}

extension ModelManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let id = downloadTask.taskIdentifier
        let value = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        MainActor.assumeIsolated {
            if let name = tasks[id] { progress[name] = value }
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let id = downloadTask.taskIdentifier
        let status = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 200
        // The temporary file is deleted when this method returns, so move it synchronously.
        let staging = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let moved = (try? FileManager.default.moveItem(at: location, to: staging)) != nil
        MainActor.assumeIsolated {
            guard let name = tasks[id] else { return }
            let destination = url(for: name)
            if status >= 400 || !moved {
                lastError = "Download of \(name) failed (HTTP \(status))."
                try? FileManager.default.removeItem(at: staging)
                return
            }
            try? FileManager.default.removeItem(at: destination)
            do {
                try FileManager.default.moveItem(at: staging, to: destination)
            } catch {
                lastError = error.localizedDescription
            }
            AppSettings.shared.selectedModelFile = name
            refresh()
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let id = task.taskIdentifier
        MainActor.assumeIsolated {
            if let name = tasks[id] {
                progress[name] = nil
                if let error, (error as NSError).code != NSURLErrorCancelled {
                    lastError = error.localizedDescription
                }
            }
            tasks[id] = nil
        }
    }
}
