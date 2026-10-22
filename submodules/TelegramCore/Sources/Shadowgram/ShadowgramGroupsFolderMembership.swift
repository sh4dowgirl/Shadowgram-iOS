import Foundation
import Postbox
import SwiftSignalKit
import ShadowgramSettings

public struct ShadowgramGroupsFolderMembership: Equatable {
    public let minMembers: Int32
    public let includedSupergroupIds: Set<EnginePeer.Id>

    func contains(_ peer: Peer) -> Bool {
        if let group = peer as? TelegramGroup {
            return group.participantCount >= Int(self.minMembers)
        }
        if let channel = peer as? TelegramChannel, case .group = channel.info, !channel.flags.contains(.isMonoforum) {
            return self.minMembers == 0 || self.includedSupergroupIds.contains(channel.id)
        }
        return false
    }

    public func contains(_ peer: EnginePeer) -> Bool {
        return self.contains(peer._asPeer())
    }

    public var predicate: ChatListFilterPredicate {
        return ChatListFilterPredicate(includePeerIds: Set(), excludePeerIds: Set(), pinnedPeerIds: [], messageTagSummary: nil, includeAdditionalPeerGroupIds: [], include: { peer, _, _, _, _ in
            return self.contains(peer)
        })
    }
}

private let shadowgramGroupsFolderSupergroupLimit = 2000
private let shadowgramGroupsFolderFetchInterval: Double = 0.4

private let shadowgramGroupsFolderRequestedIds = Atomic<Set<EnginePeer.Id>>(value: Set())

private func shadowgramIsSupergroup(_ peer: Peer) -> Bool {
    if let channel = peer as? TelegramChannel, case .group = channel.info, !channel.flags.contains(.isMonoforum) {
        return true
    }
    return false
}

private func shadowgramGroupsFolderMembershipSignal(account: Account) -> Signal<ShadowgramGroupsFolderMembership?, NoError> {
    let engine = TelegramEngine(account: account)

    let supergroupsPredicate = ChatListFilterPredicate(includePeerIds: Set(), excludePeerIds: Set(), pinnedPeerIds: [], messageTagSummary: nil, includeAdditionalPeerGroupIds: [], include: { peer, _, _, _, _ in
        return shadowgramIsSupergroup(peer)
    })

    let supergroupIds: Signal<Set<EnginePeer.Id>, NoError> = account.viewTracker.tailChatListView(groupId: .root, filterPredicate: supergroupsPredicate, count: shadowgramGroupsFolderSupergroupLimit)
    |> map { view, _ -> Set<EnginePeer.Id> in
        var result = Set<EnginePeer.Id>()
        for item in EngineChatList(view, accountPeerId: account.peerId).items {
            if let peer = item.renderedPeer.peer, shadowgramIsSupergroup(peer._asPeer()) {
                result.insert(peer.id)
            }
        }
        return result
    }
    |> distinctUntilChanged

    return ShadowgramSettings.shared.valuesSignal
    |> map { values -> Int32? in
        return values.groupsFolderEnabled ? values.groupsFolderMinMembers : nil
    }
    |> distinctUntilChanged
    |> mapToSignal { minMembers -> Signal<ShadowgramGroupsFolderMembership?, NoError> in
        guard let minMembers else {
            return .single(nil)
        }
        if minMembers == 0 {
            return .single(ShadowgramGroupsFolderMembership(minMembers: 0, includedSupergroupIds: Set()))
        }
        return supergroupIds
        |> mapToSignal { idSet -> Signal<ShadowgramGroupsFolderMembership?, NoError> in
            let ids = idSet.sorted()
            let countItems = ids.map { TelegramEngine.EngineData.Item.Peer.ParticipantCount(id: $0) }

            let counts = engine.data.subscribe(EngineDataMap(countItems))
            |> map { counts -> ShadowgramGroupsFolderMembership? in
                var included = Set<EnginePeer.Id>()
                for id in ids {
                    if let maybeCount = counts[id], let count = maybeCount, count >= Int(minMembers) {
                        included.insert(id)
                    }
                }
                return ShadowgramGroupsFolderMembership(minMembers: minMembers, includedSupergroupIds: included)
            }

            let fetchMissing: Signal<Never, NoError> = engine.data.get(EngineDataMap(countItems))
            |> mapToSignal { counts -> Signal<Never, NoError> in
                var signal: Signal<Never, NoError> = .complete()
                for id in ids {
                    if let maybeCount = counts[id], maybeCount != nil {
                        continue
                    }
                    if shadowgramGroupsFolderRequestedIds.with({ $0.contains(id) }) {
                        continue
                    }
                    let pause: Signal<Never, NoError> = Signal<Never, NoError>.complete()
                    |> delay(shadowgramGroupsFolderFetchInterval, queue: Queue.concurrentDefaultQueue())
                    let fetch: Signal<Never, NoError> = engine.peers.fetchAndUpdateCachedPeerData(peerId: id)
                    |> ignoreValues
                    |> afterCompleted {
                        let _ = shadowgramGroupsFolderRequestedIds.modify { current in
                            var current = current
                            current.insert(id)
                            return current
                        }
                    }
                    signal = signal
                    |> then(fetch)
                    |> then(pause)
                }
                return signal
            }

            return Signal { subscriber in
                let fetchDisposable = fetchMissing.start()
                let countsDisposable = counts.start(next: { value in
                    subscriber.putNext(value)
                })
                return ActionDisposable {
                    fetchDisposable.dispose()
                    countsDisposable.dispose()
                }
            }
        }
    }
    |> distinctUntilChanged
}

private final class ShadowgramGroupsFolderMembershipCache {
    static let shared = ShadowgramGroupsFolderMembershipCache()

    private let lock = NSLock()
    private var promises: [AccountRecordId: Promise<ShadowgramGroupsFolderMembership?>] = [:]

    func membership(account: Account) -> Signal<ShadowgramGroupsFolderMembership?, NoError> {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        if let promise = self.promises[account.id] {
            return promise.get()
        }
        let promise = Promise<ShadowgramGroupsFolderMembership?>()
        promise.set(shadowgramGroupsFolderMembershipSignal(account: account))
        self.promises[account.id] = promise
        return promise.get()
    }
}

public func shadowgramGroupsFolderMembership(account: Account) -> Signal<ShadowgramGroupsFolderMembership?, NoError> {
    return ShadowgramGroupsFolderMembershipCache.shared.membership(account: account)
}

public func shadowgramGroupsFolderSummary(account: Account, membership: ShadowgramGroupsFolderMembership) -> Signal<EngineChatList.GroupItem?, NoError> {
    return account.viewTracker.tailChatListView(groupId: .root, filterPredicate: membership.predicate, count: 20)
    |> map { view, _ -> EngineChatList.GroupItem? in
        let list = EngineChatList(view, accountPeerId: account.peerId)
        let items = list.items.sorted(by: { $0.index > $1.index })
        guard let top = items.first else {
            return nil
        }
        var unreadCount = 0
        for item in items {
            if let readCounters = item.readCounters, readCounters.isUnread {
                unreadCount += 1
            }
        }
        let peers = items.prefix(3).map { item -> EngineChatList.GroupItem.Item in
            return EngineChatList.GroupItem.Item(peer: item.renderedPeer, isUnread: item.readCounters?.isUnread ?? false)
        }
        return EngineChatList.GroupItem(id: .shadowgramGroups, topMessage: top.messages.last, items: Array(peers), unreadCount: unreadCount)
    }
    |> distinctUntilChanged
}
