import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import ShadowgramSettings

// Shadowgram's groups folder (Extra Settings ▸ Groups Folder).
//
// Groups with at least `minMembers` members leave the root "All" list and show up as a folder
// entry under the archive, with the archive's hide-on-scroll behaviour. Opening it shows those
// groups only. Nothing is stored or synced: the root list is filtered on the client (the same
// way collapsed communities are), and the folder screen is the root list behind a predicate.
//
// Member counts: a basic group carries its count on the peer. A supergroup's count lives only in
// its full ("cached") data, which the app loads when the chat is opened, so the folder loads the
// missing ones in the background, one request at a time, and supergroups join the folder as their
// counts arrive.

/// Which peers belong in the groups folder.
struct ShadowgramGroupsFolderMembership: Equatable {
    let minMembers: Int32
    /// Supergroups with a known member count at or above `minMembers`.
    let includedSupergroupIds: Set<EnginePeer.Id>

    func contains(_ peer: Peer) -> Bool {
        if let group = peer as? TelegramGroup {
            return group.participantCount >= Int(self.minMembers)
        }
        if let channel = peer as? TelegramChannel, case .group = channel.info, !channel.flags.contains(.isMonoforum) {
            return self.includedSupergroupIds.contains(channel.id)
        }
        return false
    }

    func contains(_ peer: EnginePeer) -> Bool {
        return self.contains(peer._asPeer())
    }

    var predicate: ChatListFilterPredicate {
        return ChatListFilterPredicate(includePeerIds: Set(), excludePeerIds: Set(), pinnedPeerIds: [], messageTagSummary: nil, includeAdditionalPeerGroupIds: [], include: { peer, _, _, _, _ in
            return self.contains(peer)
        })
    }
}

/// How many recent supergroups of the root list are considered.
private let shadowgramGroupsFolderSupergroupLimit = 300
/// Pause between two background member-count requests.
private let shadowgramGroupsFolderFetchInterval: Double = 1.5

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

    let supergroupIds: Signal<[EnginePeer.Id], NoError> = account.viewTracker.tailChatListView(groupId: .root, filterPredicate: supergroupsPredicate, count: shadowgramGroupsFolderSupergroupLimit)
    |> map { view, _ -> [EnginePeer.Id] in
        var result: [EnginePeer.Id] = []
        var seen = Set<EnginePeer.Id>()
        for item in EngineChatList(view, accountPeerId: account.peerId).items {
            if let peer = item.renderedPeer.peer, shadowgramIsSupergroup(peer._asPeer()), !seen.contains(peer.id) {
                seen.insert(peer.id)
                result.append(peer.id)
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
        return supergroupIds
        |> mapToSignal { ids -> Signal<ShadowgramGroupsFolderMembership?, NoError> in
            let countItems = ids.map { TelegramEngine.EngineData.Item.Peer.ParticipantCount(id: $0) }

            let counts = engine.data.subscribe(EngineDataMap(countItems))
            |> map { counts -> ShadowgramGroupsFolderMembership? in
                var included = Set<EnginePeer.Id>()
                for id in ids {
                    if minMembers == 0 {
                        included.insert(id)
                    } else if let maybeCount = counts[id], let count = maybeCount, count >= Int(minMembers) {
                        included.insert(id)
                    }
                }
                return ShadowgramGroupsFolderMembership(minMembers: minMembers, includedSupergroupIds: included)
            }

            // Load the counts nobody has loaded yet, slowly, so the folder fills in by itself.
            let fetchMissing: Signal<Never, NoError> = engine.data.get(EngineDataMap(countItems))
            |> mapToSignal { counts -> Signal<Never, NoError> in
                var signal: Signal<Never, NoError> = .complete()
                for id in ids {
                    if let maybeCount = counts[id], maybeCount != nil {
                        continue
                    }
                    let pause: Signal<Never, NoError> = Signal<Never, NoError>.complete()
                    |> delay(shadowgramGroupsFolderFetchInterval, queue: Queue.concurrentDefaultQueue())
                    signal = signal
                    |> then(engine.peers.fetchAndUpdateCachedPeerData(peerId: id) |> ignoreValues)
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

/// One long-lived membership computation per account, shared by every chat list that needs it.
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

func shadowgramGroupsFolderMembership(account: Account) -> Signal<ShadowgramGroupsFolderMembership?, NoError> {
    return ShadowgramGroupsFolderMembershipCache.shared.membership(account: account)
}

/// The folder's entry in the root list: newest message, a few peers and the unread count.
private func shadowgramGroupsFolderSummary(account: Account, membership: ShadowgramGroupsFolderMembership) -> Signal<EngineChatList.GroupItem?, NoError> {
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

private func shadowgramUpdate(_ update: ChatListNodeViewUpdate, membership: ShadowgramGroupsFolderMembership, folderItem: EngineChatList.GroupItem?, forceGeneric: Bool) -> ChatListNodeViewUpdate {
    let items = update.list.items.filter { item in
        guard let peer = item.renderedPeer.peer else {
            return true
        }
        return !membership.contains(peer)
    }
    var groupItems = update.list.groupItems.filter { $0.id != .shadowgramGroups }
    // Only where the root list shows its group entries at all (the archive comes with them).
    if let folderItem, !update.list.hasLater {
        groupItems.append(folderItem)
    }
    let list = EngineChatList(
        items: items,
        groupItems: groupItems,
        additionalItems: update.list.additionalItems,
        hasEarlier: update.list.hasEarlier,
        hasLater: update.list.hasLater,
        isLoading: update.list.isLoading
    )
    return ChatListNodeViewUpdate(list: list, type: forceGeneric ? .Generic : update.type, scrollPosition: forceGeneric ? nil : update.scrollPosition)
}

/// The root "All" list without the folder's groups, plus the folder entry.
func shadowgramGroupsFolderRootView(account: Account, base: Signal<ChatListNodeViewUpdate, NoError>) -> Signal<ChatListNodeViewUpdate, NoError> {
    return shadowgramGroupsFolderMembership(account: account)
    |> mapToSignal { membership -> Signal<ChatListNodeViewUpdate, NoError> in
        guard let membership else {
            return base
        }
        let summary = shadowgramGroupsFolderSummary(account: account, membership: membership)
        return Signal { subscriber in
            // Latest list update and folder entry; a new folder entry alone re-emits the last
            // update as a generic one, so it never repeats a scroll request.
            let state = Atomic<(update: ChatListNodeViewUpdate?, folderItem: EngineChatList.GroupItem?)>(value: (nil, nil))

            let summaryDisposable = summary.start(next: { folderItem in
                let update = state.modify { current in
                    return (current.update, folderItem)
                }.update
                if let update {
                    subscriber.putNext(shadowgramUpdate(update, membership: membership, folderItem: folderItem, forceGeneric: true))
                }
            })
            let baseDisposable = base.start(next: { update in
                let folderItem = state.modify { current in
                    return (update, current.folderItem)
                }.folderItem
                subscriber.putNext(shadowgramUpdate(update, membership: membership, folderItem: folderItem, forceGeneric: false))
            }, completed: {
                subscriber.putCompletion()
            })
            return ActionDisposable {
                summaryDisposable.dispose()
                baseDisposable.dispose()
            }
        }
    }
}
