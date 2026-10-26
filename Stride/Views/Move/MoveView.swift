import SwiftUI

struct MoveView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ScreenHeader(
                        title: "Start moving",
                        subtitle: Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day())
                    )

                    if model.session.isActive {
                        Button {
                            model.session.isLivePresented = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Workout in progress")
                                        .font(.headline)
                                    Text("\(model.session.kind.title) · \(Formatters.duration(model.session.elapsed))")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(18)
                            .background(model.session.kind.color.opacity(0.18), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(ActivityKind.allCases) { kind in
                        StartActivityCard(kind: kind) {
                            Task { await model.session.start(kind) }
                        }
                    }

                    Text("GPS records your route. Steps come from the motion coprocessor, with Apple Health used for daily totals.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Move")
            .alert(
                "Location needed",
                isPresented: Binding(
                    get: { model.session.errorMessage != nil },
                    set: { if !$0 { model.session.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { model.session.errorMessage = nil }
            } message: {
                Text(model.session.errorMessage ?? "")
            }
        }
    }
}

private struct StartActivityCard: View {
    let kind: ActivityKind
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(kind.color)
                    .frame(width: 64, height: 64)
                    .background(kind.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(kind.title)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                    Text(kind.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("Start")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(kind.color, in: Capsule())
                    .foregroundStyle(.black.opacity(0.85))
            }
            .padding(16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
