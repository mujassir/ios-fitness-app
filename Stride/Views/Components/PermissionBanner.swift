import SwiftUI

struct PermissionBanner: View {
    let title: String
    let detail: String
    var isWorking = false
    var actionTitle = "Allow access"
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let action {
                Button(action: action) {
                    HStack {
                        if isWorking {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isWorking ? "Waiting for Health…" : actionTitle)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isWorking)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
