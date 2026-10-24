import Foundation
import Postbox

/// The server never says that a user has blocked this account. What it does is what a block looks like
/// from outside: the user's profile photo is no longer sent and the last seen turns into "a long time
/// ago". A user with both is marked (a red no-entry sign before the name). This is a guess: someone who
/// simply has no photo and has not been online for months looks the same.
public func shadowgramLooksLikeBlockedMe(peer: EnginePeer?, presence: EnginePeer.Presence?, accountPeerId: EnginePeer.Id) -> Bool {
    guard let presence else {
        return false
    }
    if case .longTimeAgo = presence.status {
        return shadowgramLooksLikeBlockedMe(peer: peer, isLongTimeAgo: true, accountPeerId: accountPeerId)
    }
    return false
}

public func shadowgramLooksLikeBlockedMe(peer: EnginePeer?, isLongTimeAgo: Bool, accountPeerId: EnginePeer.Id) -> Bool {
    guard isLongTimeAgo, case let .user(user)? = peer else {
        return false
    }
    if user.id == accountPeerId || user.botInfo != nil || user.flags.contains(.isSupport) || peer?.isDeleted == true {
        return false
    }
    if user.id.id._internalGetInt64Value() == 777000 || !user.photo.isEmpty {
        return false
    }
    return true
}
