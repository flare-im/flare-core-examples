import SwiftUI
import FlareIMUI

// 登录屏:统一登录规格 v2。视觉取自 kit 设计 token,表单用 kit 组件搭建
// (FormFieldView + InputView + SegmentedControlView)。品牌 F logo。
// 字段:用户 ID + 协议三选(WebSocket/QUIC/竞速) 常显;WebSocket/Gateway/QUIC URL 收进
// 可折叠「服务器地址」区(默认收起,点击展开)。不再有 access token 输入(SDK 托管)。

private enum LoginSpec {
    static let logoSize: CGFloat = 64
    static let gridStep: CGFloat = 40
    static let formMaxWidth: CGFloat = 430
    static let titleSize: CGFloat = 24
    static let welcomeSize: CGFloat = 22
}

private let loginTransportOrder: [LoginTransportMode] = [.websocket, .quic, .race]
private let loginTransportLabels = ["WebSocket", "QUIC", String(localized: "Race")]

private func brandGradient(_ c: FlareColors) -> LinearGradient {
    LinearGradient(colors: [c.primaryActive, c.primary, c.info], startPoint: .topLeading, endPoint: .bottomTrailing)
}

struct LoginView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.colorScheme) private var scheme
    @State private var serverOpen = false

    private var c: FlareColors { FlareColors.of(scheme) }
    private var protocolIndex: Int { loginTransportOrder.firstIndex(of: auth.loginDraft.transportMode) ?? 0 }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    brandHeader(height: min(max(proxy.size.height * 0.32, 252), 320))
                    form
                        .frame(maxWidth: LoginSpec.formMaxWidth)
                        .frame(maxWidth: .infinity)
                }
                .frame(minHeight: proxy.size.height, alignment: .top)
            }
            .background(c.bgPrimary)
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea(edges: .top)
            .disabled(auth.isBusy)
        }
    }

    private func brandHeader(height: CGFloat) -> some View {
        ZStack {
            brandGradient(c)
            LoginGridBackground()
            VStack(spacing: FlareSizes.spacingLg) {
                FlareBrandLogo(size: LoginSpec.logoSize, variant: .plate)
                VStack(spacing: FlareSizes.spacingXs) {
                    Text("flare IM")
                        .font(.system(size: LoginSpec.titleSize, weight: .heavy))
                        .foregroundStyle(.white)
                    Text("Secure, fast instant messaging")
                        .font(.system(size: FlareSizes.fontSizeLg, weight: .regular))
                        .foregroundStyle(.white.opacity(0.88))
                }
                .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: height)
    }

    private var form: some View {
        let transportBinding = auth.draftBinding(\.transportMode)
        return VStack(alignment: .leading, spacing: FlareSizes.spacingLg) {
            VStack(alignment: .leading, spacing: FlareSizes.spacingSm) {
                Text("Welcome back")
                    .font(.system(size: LoginSpec.welcomeSize, weight: .bold))
                    .foregroundStyle(c.textPrimary)
                Text("Enter your user ID to sign in")
                    .font(.system(size: FlareSizes.fontSizeLg))
                    .foregroundStyle(c.textSecondary)
            }
            .padding(.bottom, FlareSizes.spacingSm)

            FormFieldView(
                label: String(localized: "User ID"),
                hint: String(localized: "Your user ID is assigned by the system and shown in account settings")
            ) {
                InputView(text: auth.draftBinding(\.userId), placeholder: String(localized: "Enter user ID"))
                    .identifierInput()
                    .onChange(of: auth.loginDraft.userId) { _ in auth.clearValidation() }
            }

            FormFieldView(label: String(localized: "Protocol")) {
                SegmentedControlView(options: loginTransportLabels, selectedIndex: protocolIndex) { index in
                    transportBinding.wrappedValue = loginTransportOrder[index]
                }
            }

            serverSection

            if let validationMessage = auth.validationMessage {
                HStack(spacing: FlareSizes.spacingSm) {
                    Image(systemName: "exclamationmark.circle")
                    Text(validationMessage).font(.caption)
                }
                .foregroundStyle(c.error)
            }

            if let error = auth.lastError {
                StatusBannerView(text: LoginErrorText.display(error), tone: .danger)
            }

            ButtonView(
                label: String(localized: auth.isBusy ? "Signing in..." : "Sign in"),
                size: .lg, loading: auth.isBusy, disabled: !auth.canLogin,
                block: true, icon: "forward"
            ) {
                Task { await auth.submit() }
            }
            .padding(.top, FlareSizes.spacingSm)

            VStack(spacing: FlareSizes.spacingSm) {
                Text("Your ID is assigned by the admin and shown in the invitation email")
                Text("ID-only sign-in; secure connection enabled")
            }
            .font(.caption)
            .foregroundStyle(c.textTertiary)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.top, FlareSizes.spacingSm)
        }
        .padding(.horizontal, FlareSizes.spacingXl)
        .padding(.top, 30)
        .padding(.bottom, 42)
        .background(c.bgPrimary)
    }

    /// 服务器地址区:默认收起,点击展开 WebSocket / Gateway / QUIC URL。
    @ViewBuilder
    private var serverSection: some View {
        VStack(alignment: .leading, spacing: FlareSizes.spacingLg) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { serverOpen.toggle() }
            } label: {
                HStack(spacing: FlareSizes.spacingSm) {
                    Image(systemName: "server.rack")
                        .font(.system(size: FlareSizes.fontSizeLg, weight: .medium))
                        .foregroundStyle(c.textSecondary)
                    Text("Server address")
                        .font(.system(size: FlareSizes.fontSizeLg, weight: .medium))
                        .foregroundStyle(c.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(c.textTertiary)
                        .rotationEffect(.degrees(serverOpen ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if serverOpen {
                FormFieldView(label: String(localized: "WebSocket URL")) {
                    InputView(text: auth.draftBinding(\.wsUrl), placeholder: "ws://host:60051/ws")
                        .identifierInput()
                }
                FormFieldView(
                    label: String(localized: "Gateway URL"),
                    hint: String(localized: "The SDK issues and refreshes access tokens from this gateway")
                ) {
                    InputView(text: auth.draftBinding(\.httpUrl), placeholder: "http://host:50050")
                        .identifierInput()
                }
                FormFieldView(label: String(localized: "QUIC URL")) {
                    InputView(text: auth.draftBinding(\.quicUrl), placeholder: "quic://host:60052")
                        .identifierInput()
                }
            }
        }
        .padding(FlareSizes.spacingLg)
        .background(c.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: FlareSizes.radiusLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: FlareSizes.radiusLg, style: .continuous).stroke(c.borderPrimary, lineWidth: 1))
    }
}

private struct LoginGridBackground: View {
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let step: CGFloat = LoginSpec.gridStep
                var x: CGFloat = 0
                while x <= proxy.size.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: proxy.size.height)); x += step }
                var y: CGFloat = 0
                while y <= proxy.size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: proxy.size.width, y: y)); y += step }
            }
            .stroke(.white.opacity(0.11), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}
