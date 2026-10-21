import Foundation
import Postbox
import ShadowgramSettings

// Auto reaction (Shadowgram Extra Settings). Runs inside the transaction that stores new messages
// from the server, and puts the reaction on exactly the way a tap does: a pending reaction on the
// message plus an `.updateReaction` pending action, which the regular reaction manager then sends.
//
// Who gets it, the same way privacy settings work:
// - private chats with users: everybody / contacts / nobody, then the exceptions ("always" adds a
//   user, "never" removes one);
// - groups and channels: only those added to "always" themselves;
// - "never" also wins in groups, for the group itself and for the author.
// Bots, the account itself, service messages and messages older than a few minutes (a catch-up
// after the app was closed) are skipped.

/// Messages older than this when they arrive are not reacted to.
private let shadowgramAutoReactionMaxAge: Int32 = 5 * 60

func shadowgramApplyAutoReactions(transaction: Transaction, accountPeerId: PeerId, messageIds: [MessageId]) {
    let values = ShadowgramSettings.shared.values
    if values.autoReaction.isEmpty {
        return
    }
    if values.autoReactionMode == .nobody && values.autoReactionAlwaysIds.isEmpty {
        return
    }

    let now = Int32(Date().timeIntervalSince1970)
    var reactedGroupingKeys = Set<Int64>()

    for id in messageIds {
        guard id.namespace == Namespaces.Message.Cloud else {
            continue
        }
        guard let message = transaction.getMessage(id), message.flags.contains(.Incoming) else {
            continue
        }
        if now - message.timestamp > shadowgramAutoReactionMaxAge {
            continue
        }
        if message.media.contains(where: { $0 is TelegramMediaAction }) {
            continue
        }
        let chatPeerId = id.peerId
        let authorId = message.author?.id ?? chatPeerId
        if authorId == accountPeerId {
            continue
        }
        if !shadowgramAutoReactionApplies(transaction: transaction, values: values, chatPeerId: chatPeerId, authorId: authorId) {
            continue
        }
        // One reaction per album, on its first message (where a tap would put it).
        if let groupingKey = message.groupingKey {
            if reactedGroupingKeys.contains(groupingKey) {
                continue
            }
            reactedGroupingKeys.insert(groupingKey)
        }
        shadowgramPutReaction(transaction: transaction, accountPeerId: accountPeerId, messageId: id, reaction: values.autoReaction)
    }
}

private func shadowgramAutoReactionApplies(transaction: Transaction, values: ShadowgramSettingsValues, chatPeerId: PeerId, authorId: PeerId) -> Bool {
    let never = values.autoReactionNeverIds
    if never.contains(chatPeerId.toInt64()) || never.contains(authorId.toInt64()) {
        return false
    }
    let always = values.autoReactionAlwaysIds

    if chatPeerId.namespace == Namespaces.Peer.CloudUser {
        if let user = transaction.getPeer(chatPeerId) as? TelegramUser, user.botInfo != nil, !always.contains(chatPeerId.toInt64()) {
            return false
        }
        if always.contains(chatPeerId.toInt64()) {
            return true
        }
        switch values.autoReactionMode {
        case .everybody:
            return true
        case .contacts:
            return transaction.isPeerContact(peerId: chatPeerId)
        case .nobody:
            return false
        }
    } else if chatPeerId.namespace == Namespaces.Peer.CloudGroup || chatPeerId.namespace == Namespaces.Peer.CloudChannel {
        return always.contains(chatPeerId.toInt64())
    } else {
        return false
    }
}

private func shadowgramPutReaction(transaction: Transaction, accountPeerId: PeerId, messageId: MessageId, reaction: String) {
    var sendAsPeerId = accountPeerId
    if let cachedData = transaction.getPeerCachedData(peerId: messageId.peerId) as? CachedChannelData, let sendAsPeerIdValue = cachedData.sendAsPeerId {
        sendAsPeerId = sendAsPeerIdValue
    }

    var didUpdate = false
    transaction.updateMessage(messageId, update: { currentMessage in
        let isTags = currentMessage.areReactionsTags(accountPeerId: accountPeerId)
        if isTags {
            return .skip
        }
        // Leave a message alone once it carries a reaction of ours, pending or sent.
        if currentMessage.attributes.contains(where: { $0 is PendingReactionsMessageAttribute }) {
            return .skip
        }
        if let reactions = currentMessage.effectiveReactions(isTags: isTags), reactions.contains(where: { $0.isSelected }) {
            return .skip
        }

        var storeForwardInfo: StoreMessageForwardInfo?
        if let forwardInfo = currentMessage.forwardInfo {
            storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
        }
        var attributes = currentMessage.attributes
        attributes.append(PendingReactionsMessageAttribute(accountPeerId: accountPeerId, reactions: [PendingReactionsMessageAttribute.PendingReaction(value: .builtin(reaction), sendAsPeerId: sendAsPeerId)], isLarge: false, storeAsRecentlyUsed: false, isTags: false))
        didUpdate = true
        return .update(StoreMessage(id: currentMessage.id, customStableId: nil, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
    })
    if didUpdate {
        transaction.setPendingMessageAction(type: .updateReaction, id: messageId, action: UpdateMessageReactionsAction())
    }
}
