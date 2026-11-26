import SwiftUI

/// Shared look for the top period picker and the bottom tab bar, so both
/// are the same height and their highlights have the same padding.
enum CapsuleBarMetrics {
    static let height: CGFloat = 66
    /// Gap between the bar's edge and the selected highlight.
    static let inset: CGFloat = 6
    /// Gap between neighbouring highlights.
    static let itemGap: CGFloat = 2

    static var highlightHeight: CGFloat { height - inset * 2 }

    /// Extra room at the end of scrolling screens so the last card sits
    /// clear of the floating tab bar.
    static var scrollBottomMargin: CGFloat { height + 12 }
}

extension View {
    /// Keeps scrolled content and the scroll indicator above the tab bar.
    func clearsTabBar() -> some View {
        contentMargins(.bottom, CapsuleBarMetrics.scrollBottomMargin, for: .scrollContent)
            .contentMargins(.bottom, CapsuleBarMetrics.scrollBottomMargin, for: .scrollIndicators)
    }
}

struct CapsuleBarBackground: View {
    var body: some View {
        Capsule()
            .fill(.regularMaterial)
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08)))
    }
}

struct CapsuleHighlight: View {
    var body: some View {
        Capsule().fill(Color.primary.opacity(0.14))
    }
}

/// Segmented control in the capsule style, used for Daily / Week / Month.
struct CapsuleSegmentedPicker<Item: Hashable & Identifiable>: View {
    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String

    @Namespace private var highlight

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                let isSelected = item == selection
                Button {
                    withAnimation(.snappy) { selection = item }
                } label: {
                    Text(title(item))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: CapsuleBarMetrics.highlightHeight)
                        .background {
                            if isSelected {
                                CapsuleHighlight()
                                    .matchedGeometryEffect(id: "highlight", in: highlight)
                            }
                        }
                        .padding(.horizontal, CapsuleBarMetrics.itemGap / 2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(.horizontal, CapsuleBarMetrics.inset - CapsuleBarMetrics.itemGap / 2)
        .frame(height: CapsuleBarMetrics.height)
        .background(CapsuleBarBackground())
        .sensoryFeedback(.selection, trigger: selection)
    }
}
