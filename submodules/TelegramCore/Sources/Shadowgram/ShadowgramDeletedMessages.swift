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

private func shadowgramMediaPlaceholder(_ message: Message) -> String {
    for media in message.media {
        if media is TelegramMediaImage {
            return "🖼"
        } else if let file = media as? TelegramMediaFile {
            if file.isVoice {
                return "🎤"
            } else if file.isInstantVideo || file.isVideo {
                return "🎬"
            } else if file.isSticker || file.isAnimatedSticker {
                return "🧩"
            } else {
                return "📎"
            }
        }
    }
    return "💬"
}

func shadowgramDeletedMessageQuote(_ message: Message) -> (text: String, entities: [MessageTextEntity]) {
    let author = message.author
    let name = author?.debugDisplayTitle ?? ""
    var body = message.text
    var bodyEntities: [MessageTextEntity] = []
    if body.isEmpty {
        body = shadowgramMediaPlaceholder(message)
    } else {
        for attribute in message.attributes {
            if let attribute = attribute as? TextEntitiesMessageAttribute {
                bodyEntities = attribute.entities.filter { entity in
                    if case .BlockQuote = entity.type {
                        return false
                    }
                    return true
                }
            }
        }
    }

    var entities: [MessageTextEntity] = []
    let text: String
    if name.isEmpty {
        text = body
        entities.append(contentsOf: bodyEntities)
    } else {
        text = name + "\n" + body
        let nameLength = (name as NSString).length
        entities.append(MessageTextEntity(range: 0 ..< nameLength, type: .Bold))
        if let username = author?.addressName, !username.isEmpty {
            entities.append(MessageTextEntity(range: 0 ..< nameLength, type: .TextUrl(url: "https://t.me/\(username)")))
        }
        let offset = nameLength + 1
        for entity in bodyEntities {
            entities.append(MessageTextEntity(range: (entity.range.lowerBound + offset) ..< (entity.range.upperBound + offset), type: entity.type))
        }
    }
    entities.insert(MessageTextEntity(range: 0 ..< (text as NSString).length, type: .BlockQuote(isCollapsed: false)), at: 0)
    return (text, entities)
}

/// The quote links the sender's name to `t.me/<username>`, and the server would turn that link into a
/// link preview under the message. Merges `disableLinkPreviews` into the attributes so it does not.
private func shadowgramDisablingLinkPreview(_ attributes: [MessageAttribute]) -> [MessageAttribute] {
    var flags: OutgoingContentInfoFlags = [.disableLinkPreviews]
    var result: [MessageAttribute] = []
    for attribute in attributes {
        if let attribute = attribute as? OutgoingContentInfoMessageAttribute {
            flags.formUnion(attribute.flags)
        } else {
            result.append(attribute)
        }
    }
    result.append(OutgoingContentInfoMessageAttribute(flags: flags))
    return result
}

func shadowgramForwardCopyOfDeletedMessage(sourceMessage: Message, peerId: PeerId, threadId: Int64?, forwardAttributes: [MessageAttribute], localGroupingKey: Int64?) -> EnqueueMessage? {
    var mediaReference: AnyMediaReference?
    for media in sourceMessage.media {
        if media is TelegramMediaImage || media is TelegramMediaFile {
            mediaReference = .standalone(media: media)
            break
        }
    }

    let quote = shadowgramDeletedMessageQuote(sourceMessage)
    var attributes: [MessageAttribute] = [TextEntitiesMessageAttribute(entities: quote.entities)]
    for attribute in forwardAttributes {
        if attribute is ForwardOptionsMessageAttribute {
            continue
        }
        attributes.append(attribute)
    }
    if mediaReference == nil {
        // A caption under media never gets a link preview, so only plain text needs the flag.
        attributes = shadowgramDisablingLinkPreview(attributes)
    }

    let replyToMessageId = threadId.flatMap { EngineMessageReplySubject(messageId: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: $0)), quote: nil, innerSubject: nil) }
    return .message(text: quote.text, attributes: attributes, inlineStickers: [:], mediaReference: mediaReference, threadId: threadId, replyToMessageId: replyToMessageId, replyToStoryId: nil, localGroupingKey: localGroupingKey, correlationId: nil, bubbleUpEmojiOrStickersets: [])
}

private func shadowgramLocalResourceCopy(mediaBox: MediaBox, resource: MediaResource, size: Int64?) -> LocalFileMediaResource? {
    guard mediaBox.completedResourcePath(resource) != nil else {
        return nil
    }
    let copy = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max), size: size)
    mediaBox.copyResourceData(from: resource.id, to: copy.id, synchronous: true)
    guard mediaBox.completedResourcePath(copy) != nil else {
        return nil
    }
    return copy
}

private func shadowgramUploadableMediaCopy(mediaBox: MediaBox, media: Media) -> Media? {
    if let image = media as? TelegramMediaImage {
        guard let largest = largestImageRepresentation(image.representations), let resource = shadowgramLocalResourceCopy(mediaBox: mediaBox, resource: largest.resource, size: nil) else {
            return nil
        }
        return TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: Int64.random(in: Int64.min ... Int64.max)), representations: [TelegramMediaImageRepresentation(dimensions: largest.dimensions, resource: resource, progressiveSizes: [], immediateThumbnailData: image.immediateThumbnailData)], immediateThumbnailData: image.immediateThumbnailData, reference: nil, partialReference: nil, flags: [])
    } else if let file = media as? TelegramMediaFile {
        guard let resource = shadowgramLocalResourceCopy(mediaBox: mediaBox, resource: file.resource, size: file.size) else {
            return nil
        }
        var previewRepresentations: [TelegramMediaImageRepresentation] = []
        if let thumbnail = largestImageRepresentation(file.previewRepresentations), let thumbnailResource = shadowgramLocalResourceCopy(mediaBox: mediaBox, resource: thumbnail.resource, size: nil) {
            previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: thumbnail.dimensions, resource: thumbnailResource, progressiveSizes: [], immediateThumbnailData: nil))
        }
        return TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: Int64.random(in: Int64.min ... Int64.max)), partialReference: nil, resource: resource, previewRepresentations: previewRepresentations, videoThumbnails: [], immediateThumbnailData: file.immediateThumbnailData, mimeType: file.mimeType, size: file.size, attributes: file.attributes, alternativeRepresentations: [])
    } else {
        return nil
    }
}

func shadowgramForwardsProtectedMessageAsCopy(_ message: Message) -> Bool {
    // The server refuses forwards from chats that restrict them, so with the bypass on such a message
    // is always sent as a copy, the way a kept deleted message is.
    guard ShadowgramSettings.shared.values.bypassCopyProtection else {
        return false
    }
    return message.isCopyProtected()
}

func shadowgramForwardCopyOfProtectedMessage(sourceMessage: Message, mediaBox: MediaBox, peerId: PeerId, threadId: Int64?, forwardAttributes: [MessageAttribute], localGroupingKey: Int64?) -> EnqueueMessage {
    var mediaReference: AnyMediaReference?
    for media in sourceMessage.media {
        if media is TelegramMediaImage || media is TelegramMediaFile {
            if let copy = shadowgramUploadableMediaCopy(mediaBox: mediaBox, media: media) {
                mediaReference = .standalone(media: copy)
            }
            break
        }
    }

    let quote = shadowgramDeletedMessageQuote(sourceMessage)
    var attributes: [MessageAttribute] = [TextEntitiesMessageAttribute(entities: quote.entities)]
    for attribute in forwardAttributes {
        if attribute is ForwardOptionsMessageAttribute {
            continue
        }
        attributes.append(attribute)
    }
    if mediaReference == nil {
        attributes = shadowgramDisablingLinkPreview(attributes)
    }

    let replyToMessageId = threadId.flatMap { EngineMessageReplySubject(messageId: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: $0)), quote: nil, innerSubject: nil) }
    return .message(text: quote.text, attributes: attributes, inlineStickers: [:], mediaReference: mediaReference, threadId: threadId, replyToMessageId: replyToMessageId, replyToStoryId: nil, localGroupingKey: localGroupingKey, correlationId: nil, bubbleUpEmojiOrStickersets: [])
}

func shadowgramReplacingReplyToDeletedMessage(transaction: Transaction, peerId: PeerId, message: EnqueueMessage) -> EnqueueMessage {
    guard case let .message(text, attributes, inlineStickers, mediaReference, threadId, replyToMessageId, replyToStoryId, localGroupingKey, correlationId, bubbleUpEmojiOrStickersets) = message else {
        return message
    }
    guard let replyToMessageId, let repliedMessage = transaction.getMessage(replyToMessageId.messageId), repliedMessage.shadowgramIsDeleted else {
        return message
    }

    let quote = shadowgramDeletedMessageQuote(repliedMessage)
    let prefix = quote.text + "\n"
    let offset = (prefix as NSString).length

    var userEntities: [MessageTextEntity] = []
    var updatedAttributes: [MessageAttribute] = []
    for attribute in attributes {
        if let attribute = attribute as? TextEntitiesMessageAttribute {
            userEntities = attribute.entities
        } else {
            updatedAttributes.append(attribute)
        }
    }
    var entities = quote.entities
    for entity in userEntities {
        entities.append(MessageTextEntity(range: (entity.range.lowerBound + offset) ..< (entity.range.upperBound + offset), type: entity.type))
    }
    updatedAttributes.append(TextEntitiesMessageAttribute(entities: entities))
    if mediaReference == nil {
        updatedAttributes = shadowgramDisablingLinkPreview(updatedAttributes)
    }

    let threadReply = threadId.flatMap { EngineMessageReplySubject(messageId: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: $0)), quote: nil, innerSubject: nil) }
    return .message(text: prefix + text, attributes: updatedAttributes, inlineStickers: inlineStickers, mediaReference: mediaReference, threadId: threadId, replyToMessageId: threadReply, replyToStoryId: replyToStoryId, localGroupingKey: localGroupingKey, correlationId: correlationId, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets)
}
