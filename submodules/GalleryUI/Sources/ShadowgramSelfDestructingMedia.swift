import Foundation
import UIKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import UndoUI
import ShadowgramSettings

private func shadowgramSelfDestructingMedia(_ message: Message) -> Media? {
    for media in message.media {
        if let image = media as? TelegramMediaImage, largestImageRepresentation(image.representations) != nil {
            return image
        } else if let file = media as? TelegramMediaFile {
            return file
        }
    }
    return nil
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

private func shadowgramRegularMediaCopy(mediaBox: MediaBox, media: Media) -> Media {
    if let image = media as? TelegramMediaImage, let largest = largestImageRepresentation(image.representations), let resource = shadowgramLocalResourceCopy(mediaBox: mediaBox, resource: largest.resource, size: nil) {
        return TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: Int64.random(in: Int64.min ... Int64.max)), representations: [TelegramMediaImageRepresentation(dimensions: largest.dimensions, resource: resource, progressiveSizes: [], immediateThumbnailData: image.immediateThumbnailData)], immediateThumbnailData: image.immediateThumbnailData, reference: nil, partialReference: nil, flags: [])
    } else if let file = media as? TelegramMediaFile, let resource = shadowgramLocalResourceCopy(mediaBox: mediaBox, resource: file.resource, size: file.size) {
        var previewRepresentations: [TelegramMediaImageRepresentation] = []
        if let thumbnail = largestImageRepresentation(file.previewRepresentations), let thumbnailResource = shadowgramLocalResourceCopy(mediaBox: mediaBox, resource: thumbnail.resource, size: nil) {
            previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: thumbnail.dimensions, resource: thumbnailResource, progressiveSizes: [], immediateThumbnailData: nil))
        }
        return TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: Int64.random(in: Int64.min ... Int64.max)), partialReference: nil, resource: resource, previewRepresentations: previewRepresentations, videoThumbnails: [], immediateThumbnailData: file.immediateThumbnailData, mimeType: file.mimeType, size: file.size, attributes: file.attributes, alternativeRepresentations: [])
    } else {
        return media
    }
}

public func shadowgramCanForwardSelfDestructingMedia(_ message: Message) -> Bool {
    guard ShadowgramSettings.shared.values.forwardSelfDestructingMedia, message.containsSecretMedia else {
        return false
    }
    for media in message.media {
        if media is TelegramMediaExpiredContent {
            return false
        }
    }
    return shadowgramSelfDestructingMedia(message) != nil
}

public func shadowgramForwardSelfDestructingMedia(context: AccountContext, message: Message, present: @escaping (ViewController) -> Void) {
    guard let media = shadowgramSelfDestructingMedia(message) else {
        return
    }
    let regularMedia = shadowgramRegularMediaCopy(mediaBox: context.account.postbox.mediaBox, media: media)

    func send(_ peers: [EnginePeer], peerMap: [EnginePeer.Id: EnginePeer], caption: String) {
        for peer in peers {
            var messages: [EnqueueMessage] = []
            messages.append(.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: regularMedia), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []))
            if !caption.isEmpty {
                messages.append(.message(text: caption, attributes: [], inlineStickers: [:], mediaReference: nil, threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []))
            }
            let _ = enqueueMessages(account: context.account, peerId: peer.id, messages: messages).start()
        }

        var displayPeers: [EnginePeer] = []
        for peer in peers {
            if case let .secretChat(secretPeer) = peer, let regularPeer = peerMap[secretPeer.regularPeerId] {
                displayPeers.append(regularPeer)
            } else {
                displayPeers.append(peer)
            }
        }

        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        func name(_ peer: EnginePeer) -> String {
            let title = peer.id == context.account.peerId ? presentationData.strings.DialogList_SavedMessages : peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
            return title.replacingOccurrences(of: "**", with: "")
        }
        let text: String
        var savedMessages = false
        if displayPeers.count == 1, let peer = displayPeers.first, peer.id == context.account.peerId {
            text = presentationData.strings.Conversation_ForwardTooltip_SavedMessages_One
            savedMessages = true
        } else if displayPeers.count == 1, let peer = displayPeers.first {
            text = presentationData.strings.Conversation_ForwardTooltip_Chat_One(name(peer)).string
        } else if displayPeers.count == 2, let first = displayPeers.first, let second = displayPeers.last {
            text = presentationData.strings.Conversation_ForwardTooltip_TwoChats_One(name(first), name(second)).string
        } else if let peer = displayPeers.first {
            text = presentationData.strings.Conversation_ForwardTooltip_ManyChats_One(name(peer), "\(displayPeers.count - 1)").string
        } else {
            return
        }
        present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: savedMessages, text: text), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }))
    }

    // The same peer picker that a regular forward opens, instead of the share sheet. A view-once
    // message cannot be forwarded by the server, so the picked chats get the media as a regular message.
    let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled, .doNotSearchMessages], hasFilters: true, multipleSelection: true, forwardedMessageIds: [message.id], selectForumThreads: true))
    // A plain tap on a chat row always goes through `peerSelected` (it's how the picker's row
    // tap is wired regardless of `multipleSelection`) - without this, tapping a chat did
    // nothing and the only way to send was through the multi-select batch below.
    controller.peerSelected = { [weak controller] peer, _ in
        controller?.dismiss()
        send([peer], peerMap: [peer.id: peer], caption: "")
    }
    controller.multiplePeersSelected = { [weak controller] peers, peerMap, messageText, _, _, _ in
        controller?.dismiss()
        send(peers, peerMap: peerMap, caption: messageText.string)
    }
    present(controller)
}
