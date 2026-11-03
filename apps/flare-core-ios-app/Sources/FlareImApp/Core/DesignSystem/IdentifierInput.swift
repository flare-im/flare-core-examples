import SwiftUI

extension View {
    /// User IDs, peer IDs and server URLs are exact strings. Left to the defaults, iOS
    /// capitalizes the first letter and "corrects" `ios` to `iOS`: typing `ui2-release-ios`
    /// signed in as `Ui2-release-ios`, a different and empty account, with nothing on screen
    /// to say so. Both settings are environment values, so applied to the kit `InputView`
    /// they reach the text field inside it. `textInputAutocapitalization` exists only on iOS;
    /// this package also builds for macOS, where there is no automatic capitalization.
    func identifierInput() -> some View {
        #if os(iOS)
        return textInputAutocapitalization(.never).autocorrectionDisabled()
        #else
        return autocorrectionDisabled()
        #endif
    }
}
