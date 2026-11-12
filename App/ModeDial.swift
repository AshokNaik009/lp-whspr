import SwiftUI
import UIKit

/// A rotary dial for picking the dictation mode: drag to turn, it snaps to the mode at the top.
struct ModeDial: View {
    @Environment(\.flatTheme) private var flat
    let modes: [DictationMode]
    @Binding var selectedID: String

    @State private var rotation: Double = 0
    @State private var dragDelta: Double = 0
    @State private var tickIndex: Int?
    private let feedback = UISelectionFeedbackGenerator()

    private let radius: CGFloat = 128
    private var step: Double { 360 / Double(max(modes.count, 1)) }
    private var center: CGPoint { CGPoint(x: radius + 44, y: radius + 46) }

    var body: some View {
        ZStack {
            Circle()
                .fill(.clear)
                .frame(width: (radius + 40) * 2, height: (radius + 40) * 2)
                .glass(in: Circle())
                .overlay(Circle().stroke(flat ? FlatPalette.hairline : Theme.accent.opacity(0.35), lineWidth: 1))
                .position(center)
            ForEach(Array(modes.enumerated()), id: \.element.id) { index, mode in
                item(mode, index: index)
            }
            Capsule()
                .fill(flat ? FlatPalette.ink : Theme.accent)
                .frame(width: 26, height: 4)
                .shadow(color: flat ? .clear : Theme.accent.opacity(0.8), radius: 6)
                .position(x: center.x, y: 10)
        }
        .frame(width: (radius + 44) * 2, height: radius + 60)
        .clipped()
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .onAppear { syncRotation(animated: false) }
        .onChange(of: selectedID) { _, _ in syncRotation(animated: true) }
        .onChange(of: modes.map(\.id)) { _, _ in syncRotation(animated: false) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mode")
        .accessibilityValue(modes.first { $0.id == selectedID }?.name ?? "")
        .accessibilityAdjustableAction { direction in
            guard let current = modes.firstIndex(where: { $0.id == selectedID }), !modes.isEmpty else { return }
            let next = direction == .increment ? current + 1 : current - 1
            selectedID = modes[(next % modes.count + modes.count) % modes.count].id
        }
    }

    private func item(_ mode: DictationMode, index: Int) -> some View {
        let angle = (Double(index) * step + rotation + dragDelta) * .pi / 180
        let selected = mode.id == selectedID && dragDelta == 0
        let visibility = max(0, (cos(angle) + 0.25) / 1.25)
        return Button {
            turn(to: index)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: mode.symbol)
                    .font(.jakarta(size: selected ? 20 : 16, weight: .semibold))
                    .foregroundStyle(selected && flat ? FlatPalette.canvas : Color.primary)
                    .frame(width: selected ? 50 : 40, height: selected ? 50 : 40)
                    .glass(in: Circle(), tint: selected ? (flat ? FlatPalette.ink : Theme.accent) : nil)
                Text(mode.name)
                    .font(.jakarta(.caption, selected ? .bold : .medium))
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundStyle(selected ? Color.primary : Color.primary.opacity(0.75))
        }
        .buttonStyle(.plain)
        .opacity(visibility)
        .scaleEffect(0.75 + 0.25 * visibility)
        .position(x: center.x + radius * sin(angle), y: center.y - radius * cos(angle))
        .allowsHitTesting(visibility > 0.5)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                dragDelta = Double(value.translation.width / radius) * 180 / .pi
                let nearest = index(for: rotation + dragDelta)
                if nearest != tickIndex {
                    tickIndex = nearest
                    feedback.selectionChanged()
                }
            }
            .onEnded { value in
                let predicted = Double(value.predictedEndTranslation.width / radius) * 180 / .pi
                let total = rotation + (dragDelta + predicted) / 2
                let snapped = (total / step).rounded() * step
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    rotation = snapped
                    dragDelta = 0
                }
                tickIndex = nil
                if let mode = modes[safe: index(for: snapped)] { selectedID = mode.id }
            }
    }

    private func index(for rotation: Double) -> Int {
        guard !modes.isEmpty else { return 0 }
        let raw = Int((-rotation / step).rounded())
        return (raw % modes.count + modes.count) % modes.count
    }

    /// Turns the shortest way so the mode at `index` sits at the top.
    private func turn(to index: Int) {
        var offset = (Double(index) * step + rotation).truncatingRemainder(dividingBy: 360)
        if offset > 180 { offset -= 360 }
        if offset < -180 { offset += 360 }
        feedback.selectionChanged()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { rotation -= offset }
        selectedID = modes[index].id
    }

    private func syncRotation(animated: Bool) {
        guard let index = modes.firstIndex(where: { $0.id == selectedID }), self.index(for: rotation) != index else { return }
        if animated { turn(to: index) } else { rotation = -Double(index) * step }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
