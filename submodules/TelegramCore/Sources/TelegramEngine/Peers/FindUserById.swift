import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi

func _internal_findUserById(accountPeerId: PeerId, postbox: Postbox, network: Network, userId: Int64) -> Signal<Peer?, NoError> {
    return network.request(Api.functions.users.getUsers(id: [.inputUser(.init(userId: userId, accessHash: 0))]))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<[Api.User]?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<Peer?, NoError> in
        return postbox.transaction { transaction -> Peer? in
            guard let users = result, let first = users.first else {
                return nil
            }
            let id = first.peerId
            let parsedPeers = AccumulatedPeers(transaction: transaction, chats: [], users: users)
            updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
            return transaction.getPeer(id)
        }
    }
}
