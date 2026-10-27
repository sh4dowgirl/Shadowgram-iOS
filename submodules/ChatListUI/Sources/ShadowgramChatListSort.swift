import Foundation
import TelegramCore
import SwiftSignalKit
import ShadowgramSettings

let shadowgramChatListOldestFirstWindow = 5000

let shadowgramChatListOldestFirst: Signal<Bool, NoError> = ShadowgramSettings.shared.valuesSignal
|> map { values -> Bool in
    return values.chatListOldestFirst
}
|> distinctUntilChanged

private func shadowgramChatListItem(_ item: EngineChatList.Item, index: EngineChatList.Item.Index) -> EngineChatList.Item {
    return EngineChatList.Item(
        id: item.id,
        index: index,
        messages: item.messages,
        readCounters: item.readCounters,
        isMuted: item.isMuted,
        draft: item.draft,
        threadData: item.threadData,
        renderedPeer: item.renderedPeer,
        presence: item.presence,
        hasUnseenMentions: item.hasUnseenMentions,
        hasUnseenReactions: item.hasUnseenReactions,
        hasUnseenPollVotes: item.hasUnseenPollVotes,
        forumTopicData: item.forumTopicData,
        topForumTopicItems: item.topForumTopicItems,
        hasFailed: item.hasFailed,
        isContact: item.isContact,
        autoremoveTimeout: item.autoremoveTimeout,
        storyStats: item.storyStats,
        displayAsTopicList: item.displayAsTopicList,
        isPremiumRequiredToMessage: item.isPremiumRequiredToMessage,
        mediaDraftContentType: item.mediaDraftContentType
    )
}

func shadowgramOldestFirstChatListUpdate(_ update: ChatListNodeViewUpdate) -> ChatListNodeViewUpdate {
    // Only unread chats are reordered (oldest-unread-first, pulled above everything else).
    // Read chats are passed through completely untouched, in their normal (server) order -
    // sorting never rewrites their index.
    var items: [EngineChatList.Item] = []
    var unread: [EngineChatList.Item] = []
    for item in update.list.items {
        guard case let .chatList(index) = item.index, index.pinningIndex == nil else {
            items.append(item)
            continue
        }
        if item.readCounters?.isUnread == true {
            unread.append(item)
        } else {
            items.append(item)
        }
    }
    unread.sort(by: { $0.index < $1.index })

    for (rank, item) in unread.enumerated() {
        guard case let .chatList(index) = item.index else {
            continue
        }
        let timestamp = Int32.max - 1 - Int32(rank)
        let updatedIndex = EngineChatList.Item.Index.ChatList(pinningIndex: nil, messageIndex: EngineMessage.Index(id: index.messageIndex.id, timestamp: timestamp))
        items.append(shadowgramChatListItem(item, index: .chatList(updatedIndex)))
    }
    items.sort(by: { $0.index < $1.index })

    let list = EngineChatList(
        items: items,
        groupItems: update.list.groupItems,
        additionalItems: update.list.additionalItems,
        hasEarlier: false,
        hasLater: update.list.hasLater,
        isLoading: update.list.isLoading
    )
    return ChatListNodeViewUpdate(list: list, type: update.type, scrollPosition: nil)
}
