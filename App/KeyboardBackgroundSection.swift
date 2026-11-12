import SwiftUI

/// Settings section for picking the keyboard's gradient background.
struct KeyboardBackgroundSection: View {
    @State private var background = SharedStore.keyboardBackground
    @State private var customStart = Color(hex: "6D5BFF")
    @State private var customEnd = Color(hex: "FF5E7E")

    var body: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    swatch(id: KeyboardBackground.systemID, name: "Default", fill: AnyShapeStyle(Color(.tertiarySystemFill))) {
                        apply(.system)
                    }
                    ForEach(KeyboardBackground.presets) { preset in
                        swatch(id: preset.id, name: preset.name, fill: AnyShapeStyle(preset.background.gradient!)) {
                            apply(preset.background)
                        }
                    }
                    swatch(id: KeyboardBackground.customID, name: "Custom",
                           fill: AnyShapeStyle(LinearGradient(colors: [customStart, customEnd], startPoint: .topLeading, endPoint: .bottomTrailing)),
                           symbol: "paintpalette.fill") {
                        saveCustom()
                    }
                }
                .padding(.vertical, 6)
            }
            if background.presetID == KeyboardBackground.customID {
                ColorPicker("Start colour", selection: $customStart, supportsOpacity: false)
                ColorPicker("End colour", selection: $customEnd, supportsOpacity: false)
            }
        } header: {
            Text("Keyboard background")
        } footer: {
            Text("Applies to the Leap Whisper keyboard the next time it opens.")
        }
        .onAppear {
            background = SharedStore.keyboardBackground
            if background.presetID == KeyboardBackground.customID {
                customStart = Color(hex: background.startHex)
                customEnd = Color(hex: background.endHex)
            }
        }
        .onChange(of: customStart) { _, _ in if background.presetID == KeyboardBackground.customID { saveCustom() } }
        .onChange(of: customEnd) { _, _ in if background.presetID == KeyboardBackground.customID { saveCustom() } }
    }

    private func swatch(id: String, name: String, fill: AnyShapeStyle, symbol: String? = nil, action: @escaping () -> Void) -> some View {
        let selected = background.presetID == id
        return Button(action: action) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(fill)
                    .frame(width: 58, height: 40)
                    .overlay {
                        if let symbol { Image(systemName: symbol).foregroundStyle(.white) }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(selected ? Color.white : Color.white.opacity(0.15), lineWidth: selected ? 2.5 : 1)
                    }
                Text(name)
                    .font(.jakarta(.caption2, selected ? .bold : .medium))
                    .foregroundStyle(selected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name) keyboard background")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func apply(_ value: KeyboardBackground) {
        background = value
        SharedStore.keyboardBackground = value
    }

    private func saveCustom() {
        apply(KeyboardBackground(presetID: KeyboardBackground.customID, startHex: customStart.hexString, endHex: customEnd.hexString))
    }
}
