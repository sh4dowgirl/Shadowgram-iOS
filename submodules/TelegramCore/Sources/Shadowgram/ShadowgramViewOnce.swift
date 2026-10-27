import Foundation
import Postbox
import SwiftSignalKit
import ShadowgramSettings

func shadowgramKeepsViewOnceMedia(_ message: Message) -> Bool {
    // Covers both the count-limited "View Once" media (minAutoremoveOrClearTimeout ==
    // viewOnceTimeout) and time-limited self-destructing media (an ordinary short TTL) - both
    // are `containsSecretMedia`, and both should get the same "mark as viewed" button and the
    // same immunity from the countdown starting on their own.
    return message.flags.contains(.Incoming) && message.containsSecretMedia && ShadowgramSettings.shared.values.bypassViewOnce
}

public func shadowgramViewOnceMediaIsUnreported(_ message: Message) -> Bool {
    guard shadowgramKeepsViewOnceMedia(message) else {
        return false
    }
    for attribute in message.attributes {
        if let attribute = attribute as? ConsumableContentMessageAttribute {
            return !attribute.consumed
        }
    }
    return false
}

public extension TelegramEngine.Messages {
    func shadowgramReportViewOnceMediaViewed(messageId: EngineMessage.Id) -> Signal<Never, NoError> {
        return self.account.postbox.transaction { transaction -> Void in
            guard let message = transaction.getMessage(messageId), message.flags.contains(.Incoming) else {
                return
            }
            var updatedAttributes = message.attributes
            var updateMessage = false
            for i in 0 ..< updatedAttributes.count {
                if let attribute = updatedAttributes[i] as? ConsumableContentMessageAttribute, !attribute.consumed {
                    updatedAttributes[i] = ConsumableContentMessageAttribute(consumed: true)
                    updateMessage = true
                }
            }
            guard updateMessage else {
                return
            }
            if message.id.peerId.namespace == Namespaces.Peer.SecretChat {
                if let state = transaction.getPeerChatState(message.id.peerId) as? SecretChatState, let globallyUniqueId = message.globallyUniqueId {
                    var layer: SecretChatLayer?
                    switch state.embeddedState {
                    case .terminated, .handshake:
                        break
                    case .basicLayer:
                        layer = .layer8
                    case let .sequenceBasedLayer(sequenceState):
                        layer = sequenceState.layerNegotiationState.activeLayer.secretChatLayer
                    }
                    if let layer = layer {
                        let updatedState = addSecretChatOutgoingOperation(transaction: transaction, peerId: message.id.peerId, operation: SecretChatOutgoingOperationContents.readMessagesContent(layer: layer, actionGloballyUniqueId: Int64.random(in: Int64.min ... Int64.max), globallyUniqueIds: [globallyUniqueId]), state: state)
                        if updatedState != state {
                            transaction.setPeerChatState(message.id.peerId, state: updatedState)
                        }
                    }
                }
            } else {
                addSynchronizeConsumeMessageContentsOperation(transaction: transaction, messageIds: [message.id])
            }
            transaction.updateMessage(message.id, update: { currentMessage in
                var storeForwardInfo: StoreMessageForwardInfo?
                if let forwardInfo = currentMessage.forwardInfo {
                    storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                }
                return .update(StoreMessage(id: currentMessage.id, customStableId: nil, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: updatedAttributes, media: currentMessage.media))
            })
        }
        |> ignoreValues
    }
}
