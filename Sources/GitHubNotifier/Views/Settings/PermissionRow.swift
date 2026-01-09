import SwiftUI

enum PermissionLevel {
    case required
    case recommended
    case optional

    var localizedKey: String {
        switch self {
        case .required:
            "account.perm.required"
        case .recommended:
            "account.perm.recommended"
        case .optional:
            "account.perm.optional"
        }
    }

    var color: Color {
        switch self {
        case .required:
            .red
        case .recommended:
            .orange
        case .optional:
            .secondary
        }
    }
}

struct PermissionRow: View {
    let scope: String
    let description: String
    let level: PermissionLevel

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(scope)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(4)

            Text(description.localized)
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()

            Text(level.localizedKey.localized)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(level.color)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        PermissionRow(
            scope: "notifications",
            description: "account.perm.notifications",
            level: .required
        )
        PermissionRow(
            scope: "read:user",
            description: "account.perm.read_user",
            level: .required
        )
        PermissionRow(
            scope: "repo",
            description: "account.perm.repo",
            level: .recommended
        )
    }
    .padding()
    .frame(width: 400)
}
