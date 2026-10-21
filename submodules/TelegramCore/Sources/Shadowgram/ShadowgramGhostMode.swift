import Foundation
import ShadowgramSettings

// Ghost mode (Shadowgram Extra Settings). Each check is read at the moment a request would be
// sent, so flipping a switch applies to the next request without restarting anything.

/// False while ghost mode hides read receipts: chats are then marked read on this device only.
func shadowgramSendsReadReceipts() -> Bool {
    return ShadowgramSettings.shared.values.effectiveSendReadReceipts
}

/// False while ghost mode hides "typing…" and the other input activities.
func shadowgramSendsTyping() -> Bool {
    return ShadowgramSettings.shared.values.effectiveSendTyping
}
