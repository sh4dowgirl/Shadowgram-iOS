import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import GiftItemComponent
import ShadowgramSettings
import UndoUI

private func shadowgramRemovedGiftId(_ gift: ProfileGiftsContext.State.StarGift, index: Int) -> String {
    switch gift.reference {
    case let .message(messageId):
        return "m_\(messageId.id)"
    case let .peer(peerId, id):
        return "p_\(peerId.toInt64())_\(id)"
    case let .slug(slug):
        return "s_\(slug)"
    case .none:
        return "index_\(index)"
    }
}

/// "Gift Editing": the real gifts hidden on this device with the grid's minus button, drawn as
/// the profile draws them. Tapping one puts it back.
public func shadowgramPresentRemovedGiftsScreen(context: AccountContext, peerId: EnginePeer.Id, present: @escaping (ViewController) -> Void) {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)

    let items: Signal<[ShadowgramGiftGridItem]?, NoError> = ShadowgramGiftOverrides.shared.changeSignal
    |> map { _ -> [ShadowgramGiftGridItem]? in
        var result: [ShadowgramGiftGridItem] = []
        for (index, gift) in shadowgramRemovedGifts(peerId: peerId) {
            let id = shadowgramRemovedGiftId(gift, index: index)
            let subject: GiftItemComponent.Subject
            var ribbon: GiftItemComponent.Ribbon?
            switch gift.gift {
            case let .generic(generic):
                subject = .starGift(gift: generic, price: "# \(generic.price)")
            case let .unique(unique):
                subject = .uniqueGift(gift: unique, price: nil)
                var ribbonColor: GiftItemComponent.Ribbon.Color = .blue
                for attribute in unique.attributes {
                    if case let .backdrop(_, _, innerColor, outerColor, _, _, _) = attribute {
                        ribbonColor = .custom(outerColor, innerColor)
                        break
                    }
                }
                ribbon = GiftItemComponent.Ribbon(text: "#\(unique.number)", font: .monospaced, color: ribbonColor)
            }
            result.append(ShadowgramGiftGridItem(id: id, subject: subject, ribbon: ribbon))
        }
        return result
    }

    let controller = ShadowgramGiftGridController(context: context, title: strings.shadowgramGiftEditingRemovedGifts, style: .profile, emptyText: strings.shadowgramGiftEditingRemovedGiftsEmpty, footerText: strings.shadowgramGiftEditingRemovedFooter, items: items, selected: { controller, item in
        guard let entry = shadowgramRemovedGifts(peerId: peerId).first(where: { shadowgramRemovedGiftId($0.gift, index: $0.index) == item.id }) else {
            return
        }
        shadowgramRestoreRemovedGift(peerId: peerId, index: entry.index)
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        controller.present(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: strings.shadowgramGiftRestored, timeout: nil, customUndoText: nil), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
    })
    present(controller)
}
