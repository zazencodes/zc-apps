import SwiftUI

// The look Pretty Draw shares with Pretty Keys: dark keycaps with a soft lip on a near-black bar. A selected key is a
// lighter grey, which shows the selection at a glance without competing with the colors being drawn in.
enum Theme {
    static let bar = Color(red: 0.086, green: 0.086, blue: 0.094)
    static let barEdge = Color.white.opacity(0.08)
    static let capTop = Color(red: 0.227, green: 0.227, blue: 0.239)
    static let capBottom = Color(red: 0.192, green: 0.192, blue: 0.204)
    static let capLip = Color(red: 0.133, green: 0.133, blue: 0.141)
    static let legend = Color(white: 0.9)
    static let faintLegend = Color.white.opacity(0.42)
    static let ink = Color(red: 0.114, green: 0.114, blue: 0.122)
    static let selectedTop = Color(red: 0.44, green: 0.44, blue: 0.46)
    static let selectedBottom = Color(red: 0.37, green: 0.37, blue: 0.39)
    static let selectedLip = Color(red: 0.22, green: 0.22, blue: 0.23)
    static let selectedLegend = Color.white
}

// A keycap face, lighter when `selected`, as the current tool is.
struct KeycapBackground: View {
    var selected = false
    var radius: CGFloat = 8

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            shape.fill(selected ? Theme.selectedLip : Theme.capLip)
                .offset(y: 1.5)
            shape.fill(LinearGradient(
                colors: selected ? [Theme.selectedTop, Theme.selectedBottom] : [Theme.capTop, Theme.capBottom],
                startPoint: .top, endPoint: .bottom
            ))
            shape.strokeBorder(Color.white.opacity(selected ? 0.18 : 0.07), lineWidth: 0.75)
        }
    }
}

// Legible ink on top of a color.
func ink(on color: PaletteColor) -> Color {
    color.isLight ? Theme.ink : .white
}

// A key's label, as in the shortcut sheet: one or more glyphs on a small cap.
struct KeyLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.legend)
            .padding(.horizontal, 7)
            .frame(minWidth: 26, minHeight: 24)
            .background(KeycapBackground(radius: 6))
            .padding(.bottom, 1.5)
    }
}
