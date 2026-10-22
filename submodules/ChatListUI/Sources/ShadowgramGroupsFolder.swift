import Foundation
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

// MARK: - Folder as a tab

/// Id of the client-side "Groups" tab (Extra Settings ▸ Groups Folder ▸ Separate Tab). Server
/// folder ids are small (2...255), so this one never collides. The tab is never sent to the server:
/// it is added to the tab list on the client, and a list with this filter id is the root list
/// behind the folder's predicate.
let shadowgramGroupsTabFilterId: Int32 = 1_000_001

func shadowgramGroupsTabFilter(languageCode: String) -> ChatListFilter {
    let title = ShadowgramStrings(languageCode: languageCode).groupsFolderTitle
    return .filter(
        id: shadowgramGroupsTabFilterId,
        title: ChatFolderTitle(text: title, entities: [], enableAnimations: false),
        emoticon: nil,
        data: ChatListFilterData(isShared: false, hasSharedLinks: false, categories: [], excludeMuted: false, excludeRead: false, excludeArchived: true, includePeers: ChatListFilterIncludePeers(), excludePeers: [], color: nil)
    )
}

/// Whether the groups folder currently shows as a tab.
let shadowgramGroupsFolderIsTab: Signal<Bool, NoError> = ShadowgramSettings.shared.valuesSignal
|> map { values -> Bool in
    return values.groupsFolderEnabled && values.groupsFolderPlacement == .tab
}
|> distinctUntilChanged

/// The root "All" list without the folder's groups, plus the folder entry (only when the folder
/// sits next to the archive; as a tab it has an entry of its own).
func shadowgramGroupsFolderRootView(account: Account, base: Signal<ChatListNodeViewUpdate, NoError>) -> Signal<ChatListNodeViewUpdate, NoError> {
    return combineLatest(shadowgramGroupsFolderMembership(account: account), shadowgramGroupsFolderIsTab)
    |> mapToSignal { membership, isTab -> Signal<ChatListNodeViewUpdate, NoError> in
        guard let membership else {
            return base
        }
        let summary: Signal<EngineChatList.GroupItem?, NoError>
        if isTab {
            summary = .single(nil)
        } else {
            summary = shadowgramGroupsFolderSummary(account: account, membership: membership)
        }
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
