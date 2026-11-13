import SwiftUI

// The toolbar's font list, opened from the font button: custom fonts, then the standard ones, each in its own face.
// It lives in its own panel above the canvases, which would cover a menu.
struct FontList: View {
    let custom: [String]
    let standard: [String]
    let current: String
    // As wide as the font button at least, so it lines up below it.
    let minWidth: CGFloat
    let choose: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if custom.isEmpty {
                rows(standard)
            } else {
                header("Custom")
                rows(custom)
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1.5)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 5)
                header("Standard")
                rows(standard)
            }
        }
        .padding(6)
        .frame(minWidth: minWidth, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Theme.bar.opacity(0.97))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Theme.barEdge))
                .shadow(color: .black.opacity(0.4), radius: 14, y: 4)
        )
        .padding(ToolbarPanel.margin)
        .fixedSize()
    }

    private func header(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 9.5, weight: .bold, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(Theme.faintLegend)
            .padding(.horizontal, 10)
            .padding(.top, 4)
            .padding(.bottom, 2)
    }

    private func rows(_ names: [String]) -> some View {
        ForEach(names, id: \.self) { name in
            FontRow(name: name, isCurrent: name == current) { choose(name) }
        }
    }
}

private struct FontRow: View {
    let name: String
    let isCurrent: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        let installed = FontCatalog.isInstalled(name)
        Button(action: action) {
            HStack(spacing: 16) {
                Text(installed ? FontCatalog.displayName(name) : "\(name) (missing)")
                    .font(installed ? Font(FontCatalog.font(name, size: 17)) : .system(size: 13, weight: .medium))
                    .foregroundStyle(installed ? Theme.legend : Theme.faintLegend)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.legend)
                    .opacity(isCurrent ? 1 : 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(isCurrent ? 0.1 : isHovered ? 0.06 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!installed)
        .onHover { isHovered = $0 }
    }
}
