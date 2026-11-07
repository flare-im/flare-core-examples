import SwiftUI
import FlareIMUI

/// The account entry composes the same branded shell as the Social client.
/// Access configuration and tokens remain owned by AppAccess and the SDK.
struct LoginView: View {
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        FlareAuthShell(
            product: "Flare IM",
            title: String(localized: "Welcome back"),
            subtitle: String(localized: "Enter your user ID to sign in"),
            tagline: String(localized: "MESSAGING, CONNECTED."),
            headline: String(localized: "Every conversation,\na little closer."),
            description: String(localized: "Stay connected to the people who matter. Messages, files and groups, together across your devices."),
            eyebrow: String(localized: "YOUR CONVERSATION SPACE"),
            footer: String(localized: "Use the user ID assigned to you to continue.")
        ) {
            VStack(alignment: .leading, spacing: FlareSizes.spacingLg) {
                FormFieldView(
                    label: String(localized: "User ID"),
                    required: true,
                    hint: String(localized: "Your user ID is assigned by the system and shown in account settings"),
                    error: auth.validationMessage
                ) {
                    InputView(text: auth.draftBinding(\.userId),
                              placeholder: String(localized: "Enter user ID"),
                              disabled: auth.isBusy,
                              onSubmit: submit)
                        .identifierInput()
                        .accessibilityIdentifier("auth.account")
                        .onChange(of: auth.loginDraft.userId) { _ in auth.clearValidation() }
                }
                if let error = auth.lastError {
                    StatusBannerView(text: LoginErrorText.display(error), tone: .danger)
                }
                ButtonView(
                    label: String(localized: auth.isBusy ? "Signing in..." : "Sign in"),
                    size: .lg, loading: auth.isBusy, disabled: !auth.canLogin,
                    block: true
                ) { submit() }
                .accessibilityIdentifier("auth.submit")
            }
        }
    }

    private func submit() {
        guard auth.canLogin, !auth.isBusy else { return }
        Task { await auth.submit() }
    }
}
