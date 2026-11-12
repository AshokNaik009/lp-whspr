import SwiftUI

struct ModesView: View {
    @State private var modes = SharedStore.modes

    var body: some View {
        List {
            Section {
                ForEach($modes) { $mode in
                    NavigationLink {
                        ModeEditor(mode: $mode)
                    } label: {
                        Label(mode.name, systemImage: mode.symbol)
                    }
                }
                .onDelete { modes.remove(atOffsets: $0) }
                .onMove { modes.move(fromOffsets: $0, toOffset: $1) }
            } footer: {
                Text("Modes rewrite the transcript using the optimizer chosen in Settings. A mode with empty instructions inserts the transcript verbatim.")
            }
            Section {
                Button("Add mode") {
                    modes.append(DictationMode(id: UUID().uuidString, name: "New mode", symbol: "text.bubble", instructions: ""))
                }
                Button("Reset to defaults", role: .destructive) { modes = DictationMode.defaults }
            }
        }
        .navigationTitle("Modes")
        .toolbar { EditButton() }
        .onChange(of: modes) { _, newValue in SharedStore.modes = newValue }
    }
}

private struct ModeEditor: View {
    @Binding var mode: DictationMode

    var body: some View {
        Form {
            Section("Name") { TextField("Name", text: $mode.name) }
            Section("SF Symbol") { TextField("sparkles", text: $mode.symbol).textInputAutocapitalization(.never) }
            Section("Instructions") {
                TextEditor(text: $mode.instructions).frame(minHeight: 180)
            }
        }
        .navigationTitle(mode.name)
    }
}
