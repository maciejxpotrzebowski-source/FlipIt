import SwiftUI

struct MarketOriginBadgeView: View {
    let marketType: DeckMarketType

    var body: some View {
        switch marketType {
        case .localPrivate:
            EmptyView()

        case .ownPublic:
            badgeWithArrow(
                base: "globe",
                arrow: "arrow.up",
                baseSize: 13,
                color: Color.blue,
                label: "Own public deck in Community"
            )

        case .ownPrivate:
            badgeWithArrow(
                base: "person.2",
                arrow: "arrow.up",
                baseSize: 12,
                color: Color.blue,
                label: "Own privately shared deck"
            )

        case .importedPublic(let hasUpdate):
            badgeWithArrow(
                base: "globe",
                arrow: "arrow.down",
                baseSize: 13,
                color: hasUpdate ? Color.marketUpdateYellowOrange : Color.blue,
                label: hasUpdate ? "Imported public deck (update available)" : "Imported public deck"
            )

        case .importedPrivate(let hasUpdate):
            badgeWithArrow(
                base: "person.2",
                arrow: "arrow.down",
                baseSize: 12,
                color: hasUpdate ? Color.marketUpdateYellowOrange : Color.blue,
                label: hasUpdate ? "Imported private deck (update available)" : "Imported private deck"
            )
        }
    }

    private func badgeWithArrow(base: String, arrow: String, baseSize: CGFloat, color: Color, label: LocalizedStringKey) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: base)
                .font(.system(size: baseSize, weight: .semibold))

            Image(systemName: arrow)
                .font(.system(size: 7.5, weight: .bold))
                .background(
                    Circle()
                        .fill(Color.appSecondaryGroupedBackground)
                        .padding(-1.5)
                )
                .offset(x: 4.5, y: 2)
        }
        .foregroundStyle(color)
        .padding(.trailing, 4.5)
        .fixedSize()
        .layoutPriority(1)
        .accessibilityLabel(Text(label))
    }
}
