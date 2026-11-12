import SwiftUI

enum Theme {
    static let accent = Color(red: 0.56, green: 0.47, blue: 1.0)
    static let accentSecondary = Color(red: 0.27, green: 0.66, blue: 1.0)
    static let recording = Color(red: 1.0, green: 0.36, blue: 0.52)
    static let gradient = LinearGradient(colors: [accent, accentSecondary], startPoint: .topLeading, endPoint: .bottomTrailing)
}

/// Slowly drifting purple-blue mesh gradient behind every screen. `energy` (0...1) brightens it while recording.
struct AuroraBackground: View {
    var energy: Double = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            MeshGradient(width: 3, height: 3, points: Self.points(at: t), colors: colors)
                .overlay(Color.black.opacity(0.28 - 0.16 * energy))
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.6), value: energy)
    }

    private var colors: [Color] {
        let glow = energy > 0 ? Theme.recording : Color(red: 0.45, green: 0.30, blue: 0.95)
        return [
            Color(red: 0.05, green: 0.04, blue: 0.16), Color(red: 0.20, green: 0.12, blue: 0.52), Color(red: 0.06, green: 0.10, blue: 0.30),
            Color(red: 0.12, green: 0.22, blue: 0.62), glow.opacity(0.85), Color(red: 0.30, green: 0.14, blue: 0.60),
            Color(red: 0.03, green: 0.03, blue: 0.10), Color(red: 0.10, green: 0.16, blue: 0.45), Color(red: 0.04, green: 0.05, blue: 0.14),
        ]
    }

    private static func points(at t: TimeInterval) -> [SIMD2<Float>] {
        func wave(_ base: Float, _ speed: Double, _ amplitude: Float) -> Float {
            base + amplitude * Float(sin(t * speed))
        }
        return [
            [0, 0], [wave(0.5, 0.31, 0.18), 0], [1, 0],
            [0, wave(0.45, 0.23, 0.15)], [wave(0.5, 0.37, 0.22), wave(0.42, 0.29, 0.18)], [1, wave(0.55, 0.27, 0.15)],
            [0, 1], [wave(0.5, 0.21, 0.2), 1], [1, 1],
        ]
    }
}

extension View {
    /// Liquid Glass on iOS 26+, frosted material with a hairline border on earlier systems and SDKs.
    @ViewBuilder
    func glass<S: Shape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            let base = interactive ? Glass.regular.interactive() : Glass.regular
            self.glassEffect(tint.map { base.tint($0) } ?? base, in: shape)
        } else {
            materialGlass(in: shape, tint: tint)
        }
        #else
        materialGlass(in: shape, tint: tint)
        #endif
    }

    func glassCard(cornerRadius: CGFloat = 24, tint: Color? = nil) -> some View {
        glass(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), tint: tint)
    }

    private func materialGlass<S: Shape>(in shape: S, tint: Color?) -> some View {
        background {
            ZStack {
                shape.fill(.ultraThinMaterial)
                if let tint { shape.fill(tint.opacity(0.35)) }
            }
        }
        .overlay(shape.stroke(.white.opacity(0.14), lineWidth: 1))
    }
}

/// Glowing orb used as the main mic button.
struct OrbView: View {
    var level: CGFloat
    var isRecording: Bool
    var isBusy: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isRecording && !isBusy)) { context in
            let angle = Angle.degrees(context.date.timeIntervalSinceReferenceDate * (isRecording ? 90 : 30))
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [glowColor.opacity(0.75), .clear], center: .center, startRadius: 30, endRadius: 150))
                    .frame(width: 300, height: 300)
                    .scaleEffect(1 + level * 0.45)
                    .blur(radius: 18)
                Circle()
                    .fill(AngularGradient(colors: orbColors, center: .center, angle: angle))
                    .frame(width: 132, height: 132)
                    .blur(radius: 6)
                    .overlay(
                        Circle().fill(RadialGradient(colors: [.white.opacity(0.75), .white.opacity(0)], center: UnitPoint(x: 0.34, y: 0.28), startRadius: 2, endRadius: 70))
                    )
                    .overlay(Circle().stroke(.white.opacity(0.45), lineWidth: 1))
                    .clipShape(Circle())
                    .shadow(color: glowColor.opacity(0.9), radius: 28)
                    .scaleEffect(1 + level * 0.12)
                if isBusy {
                    ProgressView().tint(.white).scaleEffect(1.5)
                } else {
                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .frame(width: 240, height: 240)
        }
        .animation(.easeOut(duration: 0.12), value: level)
        .animation(.spring(duration: 0.35), value: isRecording)
    }

    private var glowColor: Color { isRecording ? Theme.recording : Theme.accent }

    private var orbColors: [Color] {
        isRecording
            ? [Theme.recording, Color(red: 1, green: 0.55, blue: 0.3), Color(red: 0.85, green: 0.3, blue: 0.95), Theme.recording]
            : [Theme.accent, Theme.accentSecondary, Color(red: 0.85, green: 0.45, blue: 1), Theme.accent]
    }
}
