import GitHubNotifierCore
import SwiftUI

struct WelcomeView: View {
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App Icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)

            // Welcome Text
            VStack(spacing: 8) {
                Text("welcome.title".localized)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("welcome.subtitle".localized)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.horizontal)

            // Setup Section
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    Text("welcome.setup.hint".localized)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Button(action: onOpenSettings) {
                    Label("welcome.open.settings".localized, systemImage: "arrow.right.circle.fill")
                        .frame(minWidth: 140)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    WelcomeView(onOpenSettings: {})
        .frame(width: 360, height: 520)
}
