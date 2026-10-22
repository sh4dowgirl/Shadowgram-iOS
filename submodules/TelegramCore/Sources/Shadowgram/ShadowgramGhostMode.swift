import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
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

/// False while ghost mode hides story views: stories are then marked seen on this device only.
func shadowgramSendsStoryViews() -> Bool {
    return ShadowgramSettings.shared.values.effectiveSendStoryViews
}

public extension TelegramEngine.Peers {
    func shadowgramRefreshUserPresences(peerIds: [EnginePeer.Id]) -> Signal<Never, NoError> {
        let account = self.account
        return account.postbox.transaction { transaction -> [Api.InputUser] in
            return peerIds.compactMap { peerId -> Api.InputUser? in
                guard peerId.namespace == Namespaces.Peer.CloudUser, let peer = transaction.getPeer(peerId) else {
                    return nil
                }
                return apiInputUser(peer)
            }
        }
        |> mapToSignal { inputUsers -> Signal<Never, NoError> in
            if inputUsers.isEmpty {
                return .complete()
            }
            return account.network.request(Api.functions.users.getUsers(id: inputUsers))
            |> `catch` { _ -> Signal<[Api.User], NoError> in
                return .single([])
            }
            |> mapToSignal { users -> Signal<Never, NoError> in
                return account.postbox.transaction { transaction -> Void in
                    updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: AccumulatedPeers(users: users))
                }
                |> ignoreValues
            }
        }
    }
}
