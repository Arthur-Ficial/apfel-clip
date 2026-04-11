import SwiftUI

/// WelcomeSheetView — shown as a modal sheet on first launch only.
struct WelcomeSheetView: View {
    @Bindable var viewModel: PopoverViewModel

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ───────────────────────────────────────────────────────
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(red: 0.16, green: 0.49, blue: 0.22))
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 60, height: 60)

                Text("Welcome to apfel-clip")
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text("AI clipboard actions — entirely on your Mac")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)
            .padding(.bottom, 24)
            .padding(.horizontal, 32)

            Divider()

            // ── Feature bullets ──────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 16) {
                WelcomeBullet(
                    icon: "airplane",
                    title: "Works offline — airplane mode included",
                    detail: "100% on-device. No network calls. Nothing leaves your Mac."
                )
                WelcomeBullet(
                    icon: "key.slash",
                    title: "No API keys, no accounts",
                    detail: "Uses Apple Intelligence built into your Mac. Free, always."
                )
                WelcomeBullet(
                    icon: "doc.text.magnifyingglass",
                    title: "Content-aware actions",
                    detail: "Detects text, code, JSON, and errors. Shows only what's relevant."
                )
                WelcomeBullet(
                    icon: "keyboard",
                    title: "⌘⇧V from any app",
                    detail: "One hotkey opens the popover from anywhere. Pick an action. Done."
                )
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)

            Divider()

            // ── Toggle ───────────────────────────────────────────────────────
            Toggle(isOn: Binding(
                get: { viewModel.settings.checkForUpdatesOnLaunch },
                set: { enabled in Task { await viewModel.updateCheckForUpdatesOnLaunch(enabled) } }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Check for updates on launch")
                        .font(.subheadline.weight(.semibold))
                    Text("Silently checks GitHub for a newer version each time the app starts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)

            Divider()

            // ── Dismiss ──────────────────────────────────────────────────────
            Button {
                Task { await viewModel.dismissWelcome() }
            } label: {
                Text("Get Started")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.16, green: 0.49, blue: 0.22))
            .padding(.horizontal, 32)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

private struct WelcomeBullet: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(red: 0.16, green: 0.49, blue: 0.22))
                .frame(width: 24)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
