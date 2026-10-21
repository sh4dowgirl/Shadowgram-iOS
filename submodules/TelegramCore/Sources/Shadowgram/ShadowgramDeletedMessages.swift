import Foundation
import Postbox
import ShadowgramSettings

/// Marks a message that someone else deleted while "Save Deleted Messages" was on.
/// The message stays in the local history; the bubble draws a trash icon next to its time.
public final class ShadowgramDeletedMessageAttribute: MessageAttribute {
    /// When this client learned about the deletion (seconds since 1970).
    public let date: Int32

    public init(date: Int32) {
        self.date = date
    }

    required public init(decoder: PostboxDecoder) {
        self.date = decoder.decodeInt32ForKey("d", orElse: 0)
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.date, forKey: "d")
    }
}

public extension Message {
    /// True when someone else deleted this message and Shadowgram kept it.
    var shadowgramIsDeleted: Bool {
        for attribute in self.attributes {
            if attribute is ShadowgramDeletedMessageAttribute {
                return true
            }
        }
        return false
    }
}

public extension EngineMessage {
    var shadowgramIsDeleted: Bool {
        for attribute in self.attributes {
            if attribute is ShadowgramDeletedMessageAttribute {
                return true
            }
        }
        return false
    }
}

func shadowgramSavesDeletedMessages() -> Bool {
    return ShadowgramSettings.shared.values.saveDeletedMessages
}

/// Called for deletions that arrive from the server (someone else deleted the messages).
/// Deletions made in this client never get here: they remove the message locally first.
/// Returns the ids that must still be deleted for real: everything outside the cloud namespace
/// (scheduled and quick-reply messages), or everything when the setting is off.
func shadowgramKeepDeletedMessages(transaction: Transaction, ids: [MessageId]) -> [MessageId] {
    if !shadowgramSavesDeletedMessages() {
        return ids
    }
    var remaining: [MessageId] = []
    var kept: [MessageId] = []
    for id in ids {
        if id.namespace == Namespaces.Message.Cloud && id.peerId.namespace != Namespaces.Peer.SecretChat {
            kept.append(id)
        } else {
            remaining.append(id)
        }
    }
    shadowgramMarkMessagesDeleted(transaction: transaction, ids: kept)
    return remaining
}

func shadowgramMarkMessagesDeleted(transaction: Transaction, ids: [MessageId]) {
    if ids.isEmpty {
        return
    }
    let date = Int32(Date().timeIntervalSince1970)
    for id in ids {
        transaction.updateMessage(id, update: { currentMessage in
            if currentMessage.shadowgramIsDeleted {
                return .skip
            }
            var storeForwardInfo: StoreMessageForwardInfo?
            if let forwardInfo = currentMessage.forwardInfo {
                storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
            }
            var attributes = currentMessage.attributes
            attributes.append(ShadowgramDeletedMessageAttribute(date: date))
            return .update(StoreMessage(id: currentMessage.id, customStableId: nil, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
        })
    }
}
