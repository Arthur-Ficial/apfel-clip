import SwiftUI

struct WelcomeOverlayView: View {
    @Bindable var viewModel: PopoverViewModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    // ── Header ───────────────────────────────────────────────
                    VStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(red: 0.16, green: 0.49, blue: 0.22))
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 56, height: 56)

                        Text("apfel-clip")
                            .font(.system(size: 22, weight: .bold, design: .rounded))

                        Text("AI clipboard actions for macOS")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 28)
                    .padding(.bottom, 20)

                    Divider()

                    // ── Feature bullets ──────────────────────────────────────
                    VStack(alignment: .leading, spacing: 14) {
                        FeatureBullet(
                            icon: "airplane",
                            title: "Works offline",
                            detail: "100% on-device. No network calls. Nothing leaves your Mac."
                        )
                        FeatureBullet(
                            icon: "key.slash",
                            title: "No API keys or accounts",
                            detail: "Uses Apple Intelligence built into your Mac. Free, always."
                        )
                        FeatureBullet(
                            icon: "doc.text.magnifyingglass",
                            title: "Content-aware actions",
                            detail: "Detects text, code, JSON, and errors. Shows only what's relevant."
                        )
                        FeatureBullet(
                            icon: "keyboard",
                            title: "⌘⇧V from any app",
                            detail: "One hotkey opens the popover. Pick an action. Done."
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)

                    Divider()

                    // ── Toggle ───────────────────────────────────────────────
                    Toggle(isOn: Binding(
                        get: { viewModel.settings.checkForUpdatesOnLaunch },
                        set: { enabled in
                            Task { await viewModel.updateCheckForUpdatesOnLaunch(enabled) }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Check for updates on launch")
                                .font(.subheadline.weight(.semibold))
                            Text("Silently checks for a newer version each time the app starts.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)

                    Divider()

                    // ── Dismiss ──────────────────────────────────────────────
                    Button {
                        Task { await viewModel.dismissWelcome() }
                    } label: {
                        Text("Get Started")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.16, green: 0.49, blue: 0.22))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }
}

private struct FeatureBullet: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(red: 0.16, green: 0.49, blue: 0.22))
                .frame(width: 22, height: 22)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
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
