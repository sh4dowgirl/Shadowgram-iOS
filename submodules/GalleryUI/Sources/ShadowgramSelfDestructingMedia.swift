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

    let currentPresentationData = context.sharedContext.currentPresentationData.with { $0 }
    let forceTheme: PresentationTheme? = currentPresentationData.theme.overallDarkAppearance ? nil : defaultDarkColorPresentationTheme

    let shareController = context.sharedContext.makeShareController(context: context, params: ShareControllerParams(subject: .media(.standalone(media: regularMedia), nil), externalShare: false, forceTheme: forceTheme, completed: { peerIds in
        let _ = (context.engine.data.get(
            EngineDataList(
                peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
            )
        )
        |> deliverOnMainQueue).start(next: { peerList in
            let peers = peerList.compactMap { $0 }
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let text: String
            var savedMessages = false
            if peerIds.count == 1, let peerId = peerIds.first, peerId == context.account.peerId {
                text = presentationData.strings.Conversation_ForwardTooltip_SavedMessages_One
                savedMessages = true
            } else if peers.count == 1, let peer = peers.first {
                let peerName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder).replacingOccurrences(of: "**", with: "")
                text = presentationData.strings.Conversation_ForwardTooltip_Chat_One(peerName).string
            } else if peers.count == 2, let firstPeer = peers.first, let secondPeer = peers.last {
                let firstPeerName = firstPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder).replacingOccurrences(of: "**", with: "")
                let secondPeerName = secondPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder).replacingOccurrences(of: "**", with: "")
                text = presentationData.strings.Conversation_ForwardTooltip_TwoChats_One(firstPeerName, secondPeerName).string
            } else if let peer = peers.first {
                let peerName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder).replacingOccurrences(of: "**", with: "")
                text = presentationData.strings.Conversation_ForwardTooltip_ManyChats_One(peerName, "\(peers.count - 1)").string
            } else {
                return
            }
            present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: savedMessages, text: text), elevatedLayout: true, animateInAsReplacement: true, action: { _ in return false }))
        })
    }))
    present(shareController)
}
