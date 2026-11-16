import SwiftUI

// MARK: - Glass card surface

/// The design's glass card: a translucent fill, a bright top edge fading into a hairline border,
/// and a soft drop shadow.
///
/// The cards sit on the ambient background, whose lights are already soft, so a backdrop blur would
/// change nothing you can see while costing a live blur pass per card on every scrolled frame. The
/// surface is drawn as plain shapes instead, which keeps scrolling at the display's full refresh
/// rate. With Reduce Transparency on, the fill is the opaque canvas.
struct GlassSurface: ViewModifier {
    var cornerRadius: CGFloat = Theme.Radius.card
    var fill: Color = Theme.glass
    var shadow = true

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content.background {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            shape
                .fill(reduceTransparency ? AnyShapeStyle(Theme.canvas) : AnyShapeStyle(fill))
                .overlay {
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [Theme.glassHighlight, Theme.glassBorder],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                }
                .shadow(color: shadow ? Theme.cardShadow : .clear, radius: 16, y: 10)
        }
    }
}

extension View {
    /// Draws the view on the design's glass card surface.
    func glassSurface(
        cornerRadius: CGFloat = Theme.Radius.card,
        fill: Color = Theme.glass,
        shadow: Bool = true
    ) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius, fill: fill, shadow: shadow))
    }

    /// Pads the view and draws it as a full-width glass card.
    func glassCard(padding: CGFloat = Theme.Spacing.lg) -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .glassSurface()
    }
}

// MARK: - Ambient background

/// The warm canvas with two soft lights, teal at the upper left and peach at the lower right, that
/// every tab sits on.
///
/// The lights are radial gradients rather than blurred circles, so they cost nothing per frame and
/// stay fixed while the content scrolls over them.
struct AmbientBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let strength = colorScheme == .dark ? 0.55 : 0.5
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Theme.canvas
                light(Theme.ambientTeal, diameter: 520, strength: strength)
                    .position(x: 50, y: 340)
                light(Theme.ambientPeach, diameter: 560, strength: strength)
                    .position(x: size.width + 40, y: min(size.height * 0.85, 730))
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func light(_ color: Color, diameter: CGFloat, strength: Double) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color.opacity(strength), color.opacity(strength * 0.45), color.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter / 2
                )
            )
            .frame(width: diameter, height: diameter)
    }
}

extension View {
    /// Puts the ambient canvas behind the view, edge to edge.
    func ambientBackground() -> some View {
        background { AmbientBackground() }
    }
}

// MARK: - Icon tile

/// A category's symbol, filled and tinted, on a soft square of its color.
struct IconTile: View {
    let symbolName: String
    let color: Color
    var size: CGFloat = 40

    @Environment(\.colorScheme) private var colorScheme

    init(symbolName: String, colorToken: String, size: CGFloat = 40) {
        self.symbolName = symbolName
        self.color = Theme.categoryColor(for: colorToken)
        self.size = size
    }

    init(symbolName: String, color: Color, size: CGFloat = 40) {
        self.symbolName = symbolName
        self.color = color
        self.size = size
    }

    var body: some View {
        Image(systemName: symbolName)
            .symbolVariant(.fill)
            .font(.system(size: size * 0.46, weight: .medium))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(
                color.opacity(colorScheme == .dark ? 0.17 : 0.12),
                in: .rect(cornerRadius: size * 0.3, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}

/// A white symbol on a solid colored square, as Settings rows draw them.
struct SettingsIcon: View {
    let symbolName: String
    let color: Color

    var body: some View {
        Image(systemName: symbolName)
            .symbolVariant(.fill)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(color, in: .rect(cornerRadius: 9, style: .continuous))
            .accessibilityHidden(true)
    }
}

// MARK: - Text styles

/// The small uppercase heading above a group, e.g. "MONEY" or "TODAY".
struct GroupHeading: View {
    let title: Text

    init(_ title: LocalizedStringResource) {
        self.title = Text(title)
    }

    init(verbatim: Text) {
        self.title = verbatim
    }

    var body: some View {
        title
            .font(.footnote.weight(.semibold))
            .kerning(0.4)
            .textCase(.uppercase)
            .foregroundStyle(Theme.secondaryInk)
    }
}

/// A live-status chip, e.g. "● Live", whose dot pulses gently.
struct LiveChip: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(light: 0x2EC4B6, dark: 0x2EC4B6))
                .frame(width: 6, height: 6)
                .background {
                    Circle()
                        .stroke(Color(light: 0x2EC4B6, dark: 0x2EC4B6).opacity(pulse ? 0 : 0.55), lineWidth: pulse ? 1 : 4)
                        .scaleEffect(pulse ? 2.8 : 1)
                }
            Text("Live")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Theme.accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Theme.chip, in: .capsule)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

// MARK: - Entrance

/// Rises and fades a card in on its first appearance, after a short stagger, as the design's cards
/// do. With Reduce Motion on the card is simply there.
struct RiseIn: ViewModifier {
    let delay: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown || reduceMotion ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 16)
            .scaleEffect(shown || reduceMotion ? 1 : 0.985)
            .onAppear {
                guard !shown, !reduceMotion else { return }
                withAnimation(Theme.Motion.rise.delay(delay)) {
                    shown = true
                }
            }
    }
}

extension View {
    /// Rises the view in on first appearance after `delay` seconds.
    func riseIn(delay: Double = 0) -> some View {
        modifier(RiseIn(delay: delay))
    }
}

// MARK: - Buttons

/// A pressable row or tile that shrinks slightly under the finger.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(Theme.Motion.snap, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
}

/// The design's soft capsule button: accent text on a faint accent fill, or spending text on a
/// faint spending fill for a destructive action.
struct SoftCapsuleButtonStyle: ButtonStyle {
    var destructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(destructive ? Theme.spending : Theme.accent)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(destructive ? Theme.spendingSoft : Theme.accentSoft, in: .capsule)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Theme.Motion.snap, value: configuration.isPressed)
    }
}

/// The design's primary call to action: a full accent capsule with a soft accent glow beneath it.
/// Disabled, it fades rather than turning grey, as the design's Continue does.
struct AccentCapsuleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Theme.onAccent)
            .padding(.horizontal, 28)
            .frame(minHeight: 50)
            .background(Theme.accent, in: .capsule)
            .shadow(color: Theme.accentGlow, radius: 12, y: 10)
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Theme.Motion.snap, value: configuration.isPressed)
            .animation(.easeOut(duration: 0.3), value: isEnabled)
    }
}
