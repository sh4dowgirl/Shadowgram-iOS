import Foundation
import Postbox
import ShadowgramSettings

// Auto reaction (Shadowgram Extra Settings). Runs inside the transaction that stores new messages
// from the server, and puts the reaction on exactly the way a tap does: a pending reaction on the
// message plus an `.updateReaction` pending action, which the regular reaction manager then sends.
//

/// Messages older than this when they arrive are not reacted to.
private let shadowgramAutoReactionMaxAge: Int32 = 5 * 60

func shadowgramApplyAutoReactions(transaction: Transaction, accountPeerId: PeerId, messageIds: [MessageId]) {
    let settingsValues = ShadowgramSettings.shared.values
    let autoReactions = settingsValues.autoReactions
    if autoReactions.isEmpty {
        return
    }
    let reactsInGroups = settingsValues.autoReactionsInGroups

    let now = Int32(Date().timeIntervalSince1970)
    var reactedGroupingKeys = Set<Int64>()
    var accountIsPremium: Bool?

    for id in messageIds {
        guard id.namespace == Namespaces.Message.Cloud else {
            continue
        }
        let chatNamespace = id.peerId.namespace
        guard chatNamespace == Namespaces.Peer.CloudUser || chatNamespace == Namespaces.Peer.CloudGroup || chatNamespace == Namespaces.Peer.CloudChannel else {
            continue
        }
        if chatNamespace != Namespaces.Peer.CloudUser && !reactsInGroups {
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
        // A channel's own post resolves its author to the channel itself (no separate fromId),
        // so allowing CloudChannel here is what lets a channel be added as an auto-reaction
        // target, not just users.
        guard let authorId = message.author?.id, authorId != accountPeerId, authorId.namespace == Namespaces.Peer.CloudUser || authorId.namespace == Namespaces.Peer.CloudChannel else {
            continue
        }
        guard let values = autoReactions[authorId.toInt64()], !values.isEmpty else {
            continue
        }
        if let user = transaction.getPeer(authorId) as? TelegramUser, user.botInfo != nil {
            continue
        }

        var reactions: [MessageReaction.Reaction] = []
        for value in values {
            let reaction: MessageReaction.Reaction
            switch value {
            case let .emoji(emoji):
                reaction = .builtin(emoji)
            case let .custom(fileId):
                let isPremium: Bool
                if let accountIsPremium {
                    isPremium = accountIsPremium
                } else {
                    isPremium = (transaction.getPeer(accountPeerId) as? TelegramUser)?.isPremium ?? false
                    accountIsPremium = isPremium
                }
                if !isPremium {
                    continue
                }
                reaction = .custom(fileId)
            }
            guard shadowgramAutoReactionAllowed(transaction: transaction, chatPeerId: id.peerId, reaction: reaction) else {
                continue
            }
            if !reactions.contains(reaction) {
                reactions.append(reaction)
            }
        }
        guard !reactions.isEmpty else {
            continue
        }
        if let maxCount = shadowgramMaxReactionCount(transaction: transaction, chatPeerId: id.peerId) {
            reactions = Array(reactions.prefix(Int(maxCount)))
        }
        if let groupingKey = message.groupingKey {
            if reactedGroupingKeys.contains(groupingKey) {
                continue
            }
            reactedGroupingKeys.insert(groupingKey)
        }
        shadowgramPutReaction(transaction: transaction, accountPeerId: accountPeerId, messageId: id, reactions: reactions)
    }
}

private func shadowgramAutoReactionAllowed(transaction: Transaction, chatPeerId: PeerId, reaction: MessageReaction.Reaction) -> Bool {
    let cachedData = transaction.getPeerCachedData(peerId: chatPeerId)
    let settings: PeerReactionSettings?
    if let cachedData = cachedData as? CachedChannelData {
        settings = cachedData.reactionSettings.knownValue
    } else if let cachedData = cachedData as? CachedGroupData {
        settings = cachedData.reactionSettings.knownValue
    } else {
        settings = nil
    }
    guard let settings else {
        return true
    }
    switch settings.allowedReactions {
    case .all:
        return true
    case let .limited(reactions):
        return reactions.contains(reaction)
    case .empty:
        return false
    }
}

/// A group or channel admin can raise or lower how many reactions one person may put on a
/// single message; nil means no chat-specific cap is known (private chats never have one).
private func shadowgramMaxReactionCount(transaction: Transaction, chatPeerId: PeerId) -> Int32? {
    let cachedData = transaction.getPeerCachedData(peerId: chatPeerId)
    if let cachedData = cachedData as? CachedChannelData {
        return cachedData.reactionSettings.knownValue?.maxReactionCount
    } else if let cachedData = cachedData as? CachedGroupData {
        return cachedData.reactionSettings.knownValue?.maxReactionCount
    }
    return nil
}

private func shadowgramPutReaction(transaction: Transaction, accountPeerId: PeerId, messageId: MessageId, reactions reactionValues: [MessageReaction.Reaction]) {
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
        attributes.append(PendingReactionsMessageAttribute(accountPeerId: accountPeerId, reactions: reactionValues.map { PendingReactionsMessageAttribute.PendingReaction(value: $0, sendAsPeerId: sendAsPeerId) }, isLarge: false, storeAsRecentlyUsed: false, isTags: false))
        didUpdate = true
        return .update(StoreMessage(id: currentMessage.id, customStableId: nil, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
    })
    if didUpdate {
        transaction.setPendingMessageAction(type: .updateReaction, id: messageId, action: UpdateMessageReactionsAction())
    }
}
