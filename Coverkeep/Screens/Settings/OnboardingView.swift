import SwiftUI

/// First-run walkthrough: the EU story in three beats, then straight into
/// the app. Shown once (KeepCore's shared onboarding flag).
struct OnboardingView: View {
    let onFinish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            Text("Coverkeep")
                .font(.largeTitle.bold())
                .padding(.bottom, 4)
            Text("Your receipts, your rights, your deadlines.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(.bottom, 36)

            VStack(alignment: .leading, spacing: 26) {
                feature(
                    icon: "checkmark.seal",
                    title: String(localized: "Europe's rules, built in"),
                    text: String(localized: "Add a purchase and see your actual rights — the 2-year legal guarantee, the 14-day return window, national extras like the Hungarian jótállás — with official sources.")
                )
                feature(
                    icon: "doc.viewfinder",
                    title: String(localized: "Receipts that don't fade"),
                    text: String(localized: "Thermal paper fades in months. Photograph the receipt once; the full-quality copy is archived for the life of the warranty.")
                )
                feature(
                    icon: "bell.badge",
                    title: String(localized: "Reminded before it's too late"),
                    text: String(localized: "Every deadline gets a reminder before it expires — return windows count down in days.")
                )
                feature(
                    icon: "lock",
                    title: String(localized: "Yours, entirely"),
                    text: String(localized: "No account, no server, no analytics. Your documents stay on your device, and you can export everything, any time.")
                )
            }

            Spacer()

            Button {
                onFinish()
            } label: {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)

            Text(RightsCopy.disclaimer)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
        }
        .padding(28)
    }

    private func feature(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
